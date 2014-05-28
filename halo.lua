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

local inspect = require('util').inspect;
local REGISTRY = {};
local FNIDX = {};
local CONSTRUCTOR_TMPL = [==[
local function Constructor(...)
    local self = setmetatable(%s, CLASS );
    
    self:init(%s, ... );
    return self;
end

local function newindex()
    error( 'attempt to change class table' );
end

local exports = %s;
exports.new = Constructor;

return exports;
--[[setmetatable({},{
    __index = exports,
    __newindex = newindex
});
--]]

]==];

local function getFunctionId( func )
    return ('%s'):format( tostring(func) ):gsub( '^function: 0x0*', '' );
end

local function getClassId( class )
    return ('%s'):format( tostring(class) ):gsub( '^table: 0x0*', '' );
end


-- inspect hook
local function INSPECT_HOOK( value, valueType, valueFor, key )
    -- should add function-id to FNIDX table 
    if valueFor == 'value' and valueType == 'function' then
        local id = getFunctionId( value );
        FNIDX[id] = value;
        return ('FNIDX[%q]'):format( id ), true;
    end
    
    return value;
end
local INSPECT_OPTS = {
    padding = 4,
    callback = INSPECT_HOOK
};


local function deepCopy( dest, obj )
    local replica = type( dest ) == 'table' and dest or {};
    local k,v,t;
    
    for k,v in pairs( obj ) do
        t = type( v );
        if t == 'table' then
            rawset( replica, k, deepCopy( nil, v ) );
        else
            rawset( replica, k, v );
        end
    end
    
    return replica;
end


local function mergeCopy( class, metatable )
    local meta = class.metatable;
    local prop = class.property;
    local k,v,t;
    
    for k,v in pairs( metatable ) do
        t = type( v );
        -- metamethods
        if k:find( '^__[^_]' ) then
            if t == 'table' then
                rawset( meta, k, deepCopy( meta[k], v ) );
            else
                rawset( meta, k, v );
            end
        elseif t == 'table' then
            rawset( prop, k, deepCopy( prop[k], v ) );
        else
            rawset( prop, k, v );
        end
    end
end


local function printRegistry()
    print( inspect( REGISTRY ) );
end


--- initializer
local function init( self, ... )
end


local function inherits( ... )
    local defaultConstructor = { 
        class = {
            __index = {
                -- initializer
                init = init
            }
        },
        props = {},
        static = {},
        super = {}
    };
    local inheritance = {};
    local super = defaultConstructor.super;
    local module, class, classId, constructor, i;
    
    -- loading modules
    for i, module in ipairs({...}) do
        if not inheritance[module] then
            -- load module
            class = require( module );
            -- check registry index
            classId = getClassId( class );
            constructor = REGISTRY[classId];
            -- this class is not halo class
            if not constructor then
                error( ('inherit: %q is not halo class'):format( module ) );
            end
            constructor.module = module;
            rawset( super, #super + 1, constructor.class.__index.init );
            rawset( inheritance, module, true );
            deepCopy( defaultConstructor.class, constructor.class );
            deepCopy( defaultConstructor.props, constructor.props );
            deepCopy( defaultConstructor.static, constructor.static );
        end
    end
    
    return defaultConstructor;
end


local function buildConstructor( constructor )
    local ok, class, classId;
    
    --  create constructor template
    INSPECT_OPTS.udata = constructor;
    class = CONSTRUCTOR_TMPL:format(
        inspect( constructor.props, INSPECT_OPTS ),
        inspect( constructor.super, INSPECT_OPTS ),
        inspect( constructor.static, INSPECT_OPTS )
    );
    INSPECT_OPTS.udata = nil;
    -- create constructor
    -- for Lua5.1
    if setfenv then
        class = loadstring( class );
        setfenv( class, constructor.env );
        ok, class = pcall( class );
    -- for Lua5.2
    else
        ok, class = pcall( load( class, nil, 't', constructor.env ) );
    end
    
    if not ok then
        error( class );
    end
    
    -- remove old registry
    if constructor.id then
        REGISTRY[constructor.id] = nil;
    end
    -- add new registry
    classId = getClassId( class );
    constructor.id = classId;
    REGISTRY[classId] = constructor;
    
    return class;
end

-- create build hooks
local function createHooks( newIndex, getIndex, setProperty )
    return {
        -- class
        setmetatable( {}, {
            __newindex = newIndex,
            __index = getIndex
        }),
        -- method
        setmetatable( {}, {
            __newindex = newIndex,
            __index = getIndex
        }),
        setProperty
    };
end


-- class, property, method
local function class( ... )
    -- import inherits
    local constructor = inherits( ... );
    local metatable = constructor.class;
    local method = constructor.class.__index;
    
    -- property register function
    local setProperty = function( props )
        if type( props ) ~= 'table' then
            error( 'property must be type of table' );
        end
        -- overwrite property table
        constructor.props = props;
    end
    
    -- index hooks(closure)
    local classIndex = {};
    local newIndex = function( tbl, key, val )
        tbl = classIndex[tostring(tbl)];
        
        -- metamethod and class method
        if tbl == metatable then
            if type( key ) ~= 'string' then
                error( 'metamethod name must be type of string' );
            elseif key == '__index' or key == 'constructor' then
                error( ('%q field changes are disallowed'):format( key ) );
            -- metamethod
            elseif key:find( '^__*' ) then
                if val ~= nil and type( val ) ~= 'function' then
                    error( 'metamethod must be type of function' );
                end
                rawset( tbl, key, val );
            -- class method or class variable
            else
                rawset( constructor.static, key, val );
            end
        -- instance method
        elseif tbl == method then
            if type( key ) ~= 'string' then
                error( 'method name must be type of string' );
            elseif key == 'init' and type( val ) ~= 'function' then
                error( ('%q method must be type of function'):format( key ) );
            elseif val ~= nil and type( val ) ~= 'function' then
                error( 'method must be type of function' );
            end
            rawset( tbl, key, val );
        else
            error( 'unknown table' );
        end
    end
    
    -- return constructor
    local getIndex = function( tbl, key )
        tbl = classIndex[tostring(tbl)];
        if tbl == metatable then
            if key == 'constructor' then
                return buildConstructor( constructor );
            end
        end
        
        return nil;
    end
    local hooks = createHooks( newIndex, getIndex, setProperty );
    
    -- create classIndex
    classIndex = {
        [tostring(hooks[1])] = metatable,
        [tostring(hooks[2])] = method
    };
    
    -- set constructor environments
    constructor.env = {
        error = error,
        setmetatable = setmetatable,
        CLASS = constructor.class,
        FNIDX = FNIDX,
    };
    
    return unpack( hooks );
end


return {
    class = class,
    printRegistry = printRegistry
};

