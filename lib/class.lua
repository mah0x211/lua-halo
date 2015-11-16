--[[
  
  Copyright (C) 2014-2015 Masatoshi Teruya
 
  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:
 
  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.
 
  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
  THE SOFTWARE.
  
  
  lib/class.lua
  lua-halo
  Created by Masatoshi Teruya on 15/07/08.
  
--]]

local require = require;
local tableClone = require('util.table').clone;
local typeof = require('util').typeof;
local getPackageName = require('halo.util').getPackageName;
local hasImplicitSelfArg = require('halo.util').hasImplicitSelfArg;
local mergeRight = require('halo.util').mergeRight;
local setClass = require('halo.registry').setClass;
local getClass = require('halo.registry').getClass;
local getinfo = debug.getinfo;
local getupvalue = debug.getupvalue;
local setupvalue = debug.setupvalue;
-- pattern
local PTN_METAMETHOD = '^__.+';


local function checkNameConfliction( name, ... )
    for _, tbl in pairs({...}) do
        for key in pairs( tbl ) do
            assert( 
                rawequal( key, name ) == false,
                ('field %q already defined'):format( name )
            );
        end
    end
end


local function removeInheritance( inheritance, list )
    local except = rawget( list, 'except' );
    
    if except then
        local tbl;
        
        assert( 
            typeof.table( except ),
            'except must be type of table'
        );
        
        for _, scope in ipairs({ 'static', 'instance' }) do
            for _, methodName in ipairs( rawget( except, scope ) or {} ) do
                assert( 
                    typeof.string( methodName ) or typeof.finite( methodName ), 
                    ('method name must be type of string or finite number')
                    :format( methodName )
                );
                tbl = rawget( inheritance, scope );
                if methodName:find( PTN_METAMETHOD ) then
                    tbl = rawget( tbl, 'metamethod' );
                elseif scope == 'instance' then
                    tbl = rawget( tbl, 'method' );
                end
                
                if typeof.Function( rawget( tbl, methodName ) ) then
                    rawset( tbl, methodName, nil );
                end
            end
        end
    end
end


local function defineInheritance( defs, tbl )
    local base = {};
    local inheritance = {
        base = base
    };
    local pkg, class;
    
    rawset( defs, 'inheritance', inheritance );
    for _, className in ipairs( tbl ) do
        assert( 
            typeof.string( className ),
            'class name must be type of string'
        );

        -- check registry table
        class = getClass( className );
        if not class then
            -- load package by require function
            pkg = className:match( '^(.+)%.[^.]+$' );

            if pkg and typeof.string( pkg ) then
                require( pkg );
            end

            -- recheck registry table
            class = getClass( className );
            assert( class, ('class %q is not defined'):format( className ) );
        end

        mergeRight( inheritance, class );
        rawset( 
            base, className, 
            mergeRight( nil, rawget( class.instance, 'method' ) )
        );
    end
    
    removeInheritance( inheritance, tbl );
    
    return true;
end


local function defineMetamethod( target, name, fn )
    local metamethod = rawget( target, 'metamethod' );
    
    assert( 
        rawget( metamethod, name ) == nil, 
        ('metamethod %q is already defined'):format( name )
    );
    rawset( metamethod, name, fn );
end


local function defineStaticMethod( static, name, fn, isMetamethod )
    if isMetamethod then
        defineMetamethod( static, name, fn );
    else
        local method = rawget( static, 'method' );
        local property = rawget( static, 'property' );
        
        assert( 
            name ~= 'new',
            ('%q is reserved word'):format( name )
        );
        checkNameConfliction( name, method, property );
        rawset( method, name, fn );
    end
end


local function defineInstanceMethod( instance, name, fn, isMetamethod )
    if isMetamethod then
        defineMetamethod( instance, name, fn );
    else
        local method = rawget( instance, 'method' );
        local property = rawget( instance, 'property' );
        
        assert( 
            name ~= 'constructor',
            ('%q is reserved word'):format( name )
        );
        checkNameConfliction( name, method, rawget( property, 'public' ) );
        rawset( method, name, fn );
    end
end


local function defineInstanceProperty( instance, tbl )
    local property = rawget( instance, 'property' );
    local method = rawget( instance, 'method' );
    local public = rawget( property, 'public' );
    local protected = rawget( property, 'protected' );
    local target;
    
    -- public, protected
    for scope, tbl in pairs( tbl ) do
        target = rawget( property, scope );
        assert( 
            target ~= nil,
            ('unknown property type: %q'):format( scope )
        );
        for key, val in pairs( tbl ) do
            assert( 
                typeof.string( key ) or typeof.finite( key ),
                'field name must be type of string or finite number' 
            );
            assert( 
                key ~= 'constructor' or key ~= 'init',
                ('%q is reserved word'):format( key )
            );
            checkNameConfliction( key, public, protected, method );
            -- set field
            if typeof.table( val ) then
                rawset( target, key, tableClone( val ) );
            else
                rawset( target, key, val );
            end
        end
    end
    
    return true;
end


local function defineStaticProperty( static, tbl )
    local property = rawget( static, 'property' );
    local method = rawget( static, 'method' );
    
    for key, val in pairs( tbl ) do
        assert( 
            typeof.string( key ) or typeof.finite( key ),
            'field name must be type of string or finite number' 
        );
        assert( 
            key ~= 'new',
            ('field name %q is reserved word'):format( key )
        );
        checkNameConfliction( key, property, method );
        -- set field
        if typeof.table( val ) then
            rawset( property, key, tableClone( val ) );
        else
            rawset( property, key, val );
        end
    end
    
    return true;
end


local function verifyMethod( name, fn )
    local info;
    
    assert( 
        typeof.string( name ) or typeof.finite( name ),
        'method name must be type of string or finite number' 
    );
    assert( 
        typeof.Function( fn ), 
        ('method must be type of function'):format( name ) 
    );
    
    info = getinfo( fn );
    assert( 
        info.what == 'Lua', 
        ('method %q must be lua function'):format( name )
    );
    
    return hasImplicitSelfArg( fn, info );
end


local function replaceDeclUpvalue2Class( defs, decl, class )
    local idx, k, v;
    local replaceUpvalue = function( tbl )
        for _, node in ipairs({
            'metamethod',
            'method'
        }) do
            for _, fn in pairs( tbl[node] ) do
                idx = 1;
                k, v = getupvalue( fn, idx );
                while k do
                    -- lookup table upvalue
                    if typeof.table( v ) then
                        if v == decl then
                            setupvalue( fn, idx, class );
                        elseif k == '_ENV' then
                            for ek, ev in pairs( v ) do
                                if typeof.table( ev ) and ev == decl then
                                    v[ek] = class;
                                end
                            end
                        end
                    end
                    
                    -- check next upvalue
                    idx = idx + 1;
                    k, v = getupvalue( fn, idx );
                end
            end
        end
    end
    
    replaceUpvalue( defs.instance );
    replaceUpvalue( defs.static );
end


local function declClass( _, className )
    local source = getinfo( 2, 'S' ).source;
    local pkgName = getPackageName();
    local defs = {
        static = {
            property = {},
            method = {},
            metamethod = {}
        },
        instance = {
            property = {
                public = {},
                protected = {}
            },
            method = {},
            metamethod = {}
        }
    };
    local defined = {
        inheritance = false,
        static      = false,
        instance    = false
    };
    local exports;
    
    -- append package-name
    if pkgName then
        pkgName = pkgName .. '.' .. className;
    else
        pkgName = className;
    end
    
    assert( 
        typeof.string( className ), 
        'class name must be type of string' 
    );
    assert( 
        getClass( pkgName ) == nil, 
        ('class %q already defined'):format( className )
    );
    
    -- declaration method table
    local DECLARATOR = {
        -- define inheritance
        inherits = function( tbl )
            assert( 
                rawget( defined, 'inheritance' ) == false,
                'inheritance already defined'
            );
            assert( 
                typeof.table( tbl ), 
                'inheritance must be type of table'
            );
            rawset( defined, 'inheritance', defineInheritance( defs, tbl ) );
        end,
        
        -- define property
        property = function( self, tbl )
            local scope, proc;
            
            -- instance property
            if tbl then
                scope = 'instance';
                proc = defineInstanceProperty;
            -- static property
            else
                scope = 'static';
                proc = defineStaticProperty;
                tbl = self;
            end
            
            assert( 
                rawget( defined, scope ) == false,
                ('%q property already defined'):format( scope )
            );
            assert( 
                typeof.table( tbl ), 
                'property must be type of table'
            );
            rawset( defined, scope, proc( rawget( defs, scope ), tbl ) );
        end
    };
    
    -- return class declarator
    local decl = {};
    local class = {};
    
    setmetatable( decl, {
        -- protect metatable
        __metatable = 1,
        -- declare static methods by table
        __call = function( self, tbl )
            assert( typeof.table( tbl ), 'method list must be type of table' );
            
            for name, fn in pairs( tbl ) do
                assert( 
                    not verifyMethod( name, fn ), 
                    ('%q is not type of static method'):format( name )
                );
                -- define static method
                defineStaticMethod( 
                    rawget( defs, 'static' ), name, fn, 
                    name:find( PTN_METAMETHOD ) 
                );
            end
        end,
        
        -- property/inheritance declaration or class exports
        __index = function( _, name )
            if typeof.string( name ) then
                if name == 'exports' then
                    assert( 
                        exports == nil,
                        ('class %q already exported'):format( className )
                    );
                    replaceDeclUpvalue2Class( defs, decl, class );
                    exports = setClass( class, source, pkgName, defs );
                    
                    return exports;
                end
                
                return rawget( DECLARATOR, name );
            end
            
            assert( false, ('%q is unknown declaration'):format( name ) );
        end,
        
        -- method declaration
        __newindex = function( _, name, fn )
            local hasSelf = verifyMethod( name, fn );
            local scope, proc;
            
            if hasSelf then
                scope = 'instance';
                proc = defineInstanceMethod;
            else
                scope = 'static';
                proc = defineStaticMethod;
            end
            
            proc( 
                rawget( defs, scope ), name, fn, 
                name:find( PTN_METAMETHOD ) 
            );
        end
    });
    
    return decl;
end


return declClass;
