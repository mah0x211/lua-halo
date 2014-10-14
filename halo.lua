--[[
  
  Copyright (C) 2014 Masatoshi Teruya
 
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
  
  
  halo.lua
  lua-halo
  Created by Masatoshi Teruya on 14/05/28.
  
--]]

local LUA_VERS = tonumber( _VERSION:match( 'Lua (.+)$' ) );
local require = require;
local util = require('util');
local eval = util.eval;
local typeof = util.typeof;
local inspect = util.inspect;
local REGISTRY = {};
-- pattern
local PTN_METAMETHOD = '^__.+';
-- default
local function DEFAULT_INIT(self) return self; end
-- template
local TMPL_PREPATE_METHOD = [==[
local error = error;
local rawget = rawget;
local rawset = rawset;
local setmetatable = setmetatable;
local PROPERTY_IDX = PROPERTY_IDX;
local PROTECTED = setmetatable({},{
    __mode = 'k';
});

local function getProtected( instance )
    return rawget( PROTECTED, instance );
end

local function noNewIndex()
    error( 'attempted to assign to readonly property', 2 );
end

local function noIndex()
    error( 'attempted to access to undefined property', 2 );
end

local METHOD_IDX = %s;

do
    local BASE_IDX = {};
    local BASE = setmetatable({}, {
        __newindex = noNewIndex,
        __index = setmetatable( BASE_IDX, {
            __index = noIndex
        })
    });
    local k, fn, env;
    
    for k,fn in pairs( METHOD_IDX ) do
        fn, env = cloneFunction( fn );
        rawset( env, 'protected', getProtected );
        rawset( env, 'base', BASE );
        rawset( METHOD_IDX, k, fn );
    end
    
    for k,fn in pairs("$BASE$") do
        rawset( BASE_IDX, k, fn );
    end
end


]==];
local TMPL_INDEX_METAMETHOD = [==[{
            __index = function( _, ... )
                return METHOD_IDX[%q]( self, ... );
            end
        }]==];
local TMPL_METHOD_METATABLE = [==[setmetatable(%s, %s)]==];
local TMPL_CONSTRUCTOR = [==[
"$PREPARE_METHOD$"

local function Constructor(...)
    local self;
    
    self = setmetatable(%s, %s);
    
    rawset( PROTECTED, self, %s );
    
    return self:init( ... );
end

return Constructor;
]==];


local function getUpvalues( fn )
    local upv = {};
    local i = 1;
    local k,v, env;
    
    while true do
        k,v = debug.getupvalue( fn, i );
        if not k then 
            break;
        elseif env == nil and k == '_ENV' then
            env = v;
        end
        rawset( upv, i, { key = k, val = v } );
        i = i + 1;
    end
    
    return upv, env;
end


local function setUpvalues( fn, upv, except )
    for i,kv in ipairs( upv ) do
        if kv.key ~= except then
            debug.setupvalue( fn, i, kv.val );
        end
    end
end


local function getEnv( fn )
    local upv, env = getUpvalues( fn );
    
    if LUA_VERS > 5.1 then
        if not env then
            env = _G;
        end
    else
        env = {};
        for k,v in pairs( getfenv( fn ) or {} ) do
            rawset( env, k, v );
        end
    end
    
    return upv, env;
end


local function cloneFunction( fn )
    local upv, env = getEnv( fn );
    local err;
    
    fn = string.dump( fn );
    fn = assert( eval( fn, env ) );
    setUpvalues( fn, upv );
    
    return fn, env;
end


local function getFunctionId( func )
    return ('%s'):format( tostring(func) ):gsub( '^function: 0x0*', '' );
end

-- inspect hook
local function inspectHook( value, valueType, valueFor, key, ctx )
    -- should add function-id to FNIDX table 
    if valueFor == 'value' and valueType == 'function' then
        local id = getFunctionId( value );
        
        rawset( ctx.fnindex, id, value );
        
        return ('%s[%q]'):format( ctx.prefix, id ), true;
    end
    
    return value;
end


local function makeTemplate( defs, env )
    local METHOD_IDX = rawget( env, 'METHOD_IDX' );
    local opts = {
        padding = 4,
        callback = inspectHook,
        udata = {
            fnindex = METHOD_IDX,
            prefix = 'METHOD_IDX'
        }
    };
    local propertyOpts = {
        padding = 4,
        callback = inspectHook,
        udata = {
            fnindex = rawget( env, 'PROPERTY_IDX' ),
            prefix = 'PROPERTY_IDX'
        }
    };
    local repls = {
        ['$CONSTRUCTOR$']   = 'Constructor',
        ['$BASE$']          = '{}';
    };
    local base = rawget( defs, 'base' );
    local instance = rawget( defs, 'instance' );
    local method = rawget( instance, 'method' );
    local metamethod = rawget( instance, 'metamethod' );
    local property = rawget( instance, 'property' );
    local public = rawget( property, 'public' );
    local protected = rawget( property, 'protected' );
    local mmindex = rawget( metamethod, '__index' );
    local tmpl;
    
    if base then
        rawset( repls, '$BASE$', inspect( base or {}, opts ) )
    end
    
    -- render template of constructor
    rawset( metamethod, '__index', '$METHOD$' );
    tmpl = TMPL_CONSTRUCTOR:format(
        inspect( public, propertyOpts ),
        inspect( metamethod, opts ),
        inspect( protected, propertyOpts )
    );
    rawset( metamethod, '__index', nil );

    -- render template of metatable
    opts.padding = 8;
    rawset( method, 'constructor', '$CONSTRUCTOR$' );
    -- construct __index metamethod
    if mmindex then
        local id = getFunctionId( mmindex );
        -- set mmindex id
        rawset( opts.udata.fnindex, id, mmindex );
        rawset( repls, '$METHOD$', TMPL_METHOD_METATABLE:format(
            inspect( method, opts ),
            TMPL_INDEX_METAMETHOD:format( id )
        ));
    else
        rawset( repls, '$METHOD$', inspect( method, opts ) );
    end
    rawset( method, 'constructor', nil );
    rawset( metamethod, '__index', mmindex );
    
    -- render template of private variables
    opts.padding = 0;
    rawset( 
        repls, '$PREPARE_METHOD$', 
        TMPL_PREPATE_METHOD:format( inspect( METHOD_IDX, opts ) )
    );
    
    -- replace templates
    return tmpl:gsub( '"(%$[^$"]+%$)"', repls )
               :gsub( '"(%$[^$"]+%$)"', repls );
end


local function mergeRight( dest, src )
    local tbl = typeof.table( dest ) and dest or {};
    
    for k,v in pairs( src ) do
        if typeof.table( v ) then
            rawset( tbl, k, mergeRight( tbl and rawget( tbl, k ), v ) );
        else
            rawset( tbl, k, v );
        end
    end
    
    return tbl;
end


local function mergeLeft( dest, src )
    local lv;
    
    for k,v in pairs( src ) do
        lv = rawget( dest, k );
        if not lv then
            if typeof.table( v ) then
                rawset( dest, k, mergeRight( nil, v ) );
            else
                rawset( dest, k, v );
            end
        -- merge table
        elseif typeof.table( v ) and typeof.table( lv ) then
            mergeLeft( lv, v );
        end
    end
end


local function preprocess( defs )
    local inheritance = rawget( defs, 'inheritance' );
    local instance = rawget( defs, 'instance' );
    local method = rawget( instance, 'method' );
    
    -- remove inheritance table
    if inheritance then
        rawset( defs, 'inheritance', nil );
        mergeLeft( defs, inheritance );
    end
    
    -- set default init function
    if not rawget( method, 'init' ) then
        rawset( method, 'init', DEFAULT_INIT );
    end
end


local function postprocess( className, defs, constructor )
    local static = rawget( defs, 'static' );
    local method = rawget( static, 'method' );
    local metamethod = rawget( static, 'metamethod' );
    local newtbl = {};
    
    -- set class constructor
    rawset( method, 'new', constructor );
    mergeLeft( newtbl, rawget( static, 'property' ) );
    mergeLeft( newtbl, method );
    -- check metamethod
    for _ in pairs( metamethod ) do
        newtbl = setmetatable( newtbl, metamethod );
        break;
    end
    -- add to registry table
    rawset( REGISTRY, className, defs );
    
    return newtbl;
end


local function classExports( className, defs )
    local env = {
        METHOD_IDX = {},
        PROPERTY_IDX = {},
        cloneFunction = cloneFunction,
        error = error,
        setmetatable = setmetatable,
        pairs = pairs,
        rawget = rawget,
        rawset = rawset
    };
    local tmpl, fn, ok, err, constructor;
    
    -- create template
    preprocess( defs );
    tmpl = makeTemplate( defs, env );
    
    -- create constructor
    fn, err = eval( tmpl, env );
    assert( not err, err );
    ok, constructor = pcall( fn );
    assert( ok, constructor );
    
    -- cleanup env
    for k in pairs( env ) do
        rawset( env, k, nil );
    end
    
    return postprocess( className, defs, constructor );
end


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
        pkg = className:match( '^(.+)%.[^.]+$' );
        if pkg and typeof.string( pkg ) then
            require( pkg );
        end
        
        -- check registry table
        class = rawget( REGISTRY, className );
        assert( class, ('class %q is not defined'):format( className ) );
        
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
                rawset( target, key, util.table.clone( val ) );
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
            rawset( property, key, util.table.clone( val ) );
        else
            rawset( property, key, val );
        end
    end
    
    return true;
end


local function hasImplicitSelfArg( method, info )
    -- for Lua5.2
    if LUA_VERS > 5.1 then
        return debug.getlocal( method, 1 ) == 'self';
    -- for Lua5.1
    else
        local head, tail = info.linedefined, info.lastlinedefined;
        local lineno = 0;
        local src = {};
        
        for line in io.lines( info.source:sub( 2 ) ) do
            lineno = lineno + 1;
            if lineno > tail then
                break;
            elseif lineno >= head then
                rawset( src, #src + 1, line );
            end
        end
        
        src = table.concat( src, '\n' );
        return src:find( '^%s*function%s[^:%s]+%s*:%s*[^%s]+%s*[(]' ) ~= nil;
    end
    
    return false;
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
    
    info = debug.getinfo( fn );
    assert( 
        info.what == 'Lua', 
        ('method %q must be lua function'):format( name )
    );
    
    return hasImplicitSelfArg( fn, info );
end


local function getPackagePath()
    local i = 1;
    local info, prev;
    
    repeat
        info = debug.getinfo( i, 'nS' );
        if info then
            if rawget( info, 'what' ) == 'C' and 
               rawget( info, 'name' ) == 'require' then
                return rawget( prev, 'source' );
            end
            prev = info;
            i = i + 1;
        end
    until info == nil;
    
    return nil;
end


local function getPackageName()
    local src = getPackagePath();
    
    if src then
        local lpath = util.string.split( package.path, ';' );
        
        -- sort by length
        table.sort( lpath, function( a, b )
            return #a > #b;
        end);
        
        -- find filepath
        for _, path in ipairs( lpath ) do
            path = src:match( path:gsub( '%?.+$', '(.+)[.]lua' ) );
            if path then
                return path:gsub( '/', '.' );
            end
        end
    end
    
    return nil;
end


local function createClass( _, className )
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
        rawget( REGISTRY, pkgName ) == nil, 
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
    return setmetatable({},{
        -- declare static methods by table
        __call = function( self, tbl )
            local hasSelf;
            
            assert( typeof.table( tbl ), 'method list must be type of table' );
            
            for name, fn in pairs( tbl ) do
                hasSelf = verifyMethod( name, fn );
                assert( 
                    not hasSelf, 
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
                    exports = classExports( pkgName, defs );
                    
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
end


local function instanceof( instance, class )
    local mt = getmetatable( instance );
    return mt ~= nil and typeof.table( class ) and 
           rawget( mt.__index, 'constructor' ) == class.new;
end

local function printRegistry()
    print( inspect( REGISTRY ) );
end

return {
    class = setmetatable({},{
        __index = createClass
    }),
    instanceof = instanceof,
    printRegistry = printRegistry
};
