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
local require = require;
local REGISTRY = {};
local CONSTRUCTOR_TMPL = [==[
local function Constructor(...)
    local self = setmetatable( %s, CLASS );
    
    return self, self:init( ... );
end

local EXPORTS = %s;
EXPORTS.new = Constructor;

return EXPORTS;

]==];

local function getFunctionId( func )
    return ('%s'):format( tostring(func) ):gsub( '^function: 0x0*', '' );
end

local function getClassId( class )
    return ('%s'):format( tostring(class) ):gsub( '^table: 0x0*', '' );
end


-- inspect hook
local function INSPECT_HOOK( value, valueType, valueFor, key, FNIDX )
    -- should add function-id to FNIDX table 
    if valueFor == 'value' and valueType == 'function' then
        local id = getFunctionId( value );
        
        rawset( FNIDX, id, value );
        
        return ('FNIDX[%q]'):format( id ), true;
    end
    
    return value;
end

local INSPECT_OPTS_LOCAL = {
    padding = 0,
    callback = INSPECT_HOOK
};
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
            rawset( replica, k, deepCopy( dest and rawget( dest, k ), v ) );
        else
            rawset( replica, k, v );
        end
    end
    
    return replica;
end


local function mergeCopy( dest, obj )
    local k,v,destVal;
    
    for k,v in pairs( obj ) do
        destVal = rawget( dest, k );
        if not destVal then
            if type( v ) == 'table' then
                destVal = {};
                mergeCopy( destVal, v );
                rawset( dest, k, destVal );
            else
                rawset( dest, k, v );
            end
        -- merge table
        elseif type( v ) == 'table' and type( destVal ) == 'table' then
            mergeCopy( destVal, v );
        end
    end
end


-- protect table
local function attemptNewIndex()
    error( 'attempt to change the super table' );
end

local function protectTable( target )
    local tbl = deepCopy( nil, target );
    local k,v;
    
    for k,v in pairs( tbl ) do
        tbl[k] = setmetatable( {}, {
            __newindex = attemptNewIndex,
            __index = v
        })
    end
    
    return setmetatable( {}, {
        __newindex = attemptNewIndex,
        __index = tbl
    })
end


local function printRegistry()
    print( inspect( REGISTRY ) );
end


--- initializer
local function init()
end


local function import( module )
    if not package.loaded[module] then
        -- load module
        local class = require( module );
        -- check registry index
        local constructor = rawget( REGISTRY, getClassId( class ) );
        
        -- found class constructor
        if constructor then
            -- add module name
            rawset( constructor, 'module', module );
        end
        
        return class;
    end
    
    return require( module );
end
-- swap require with import
_G.require = import;

local function getClassConstructor( module )
    local class = import( module );
    return rawget( REGISTRY, getClassId( class ) );
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
        -- method table of super classes
        super = {},
        -- set constructor environments
        env = {
            error = error,
            setmetatable = setmetatable,
            FNIDX = {}
        }
    };
    local inheritance = {};
    local super = defaultConstructor.super;
    local module, constructor, i, _;
    
    -- set constructor.class to environments
    defaultConstructor.env.CLASS = defaultConstructor.class;
    
    -- loading modules
    for i, module in ipairs({...}) do
        if not rawget( inheritance, module ) then
            constructor = getClassConstructor( module );
            -- this class is not halo class
            if not constructor then
                error( ('inherit: %q is not halo class'):format( module ) );
            end
            
            rawset( inheritance, module, true );
            -- copy super, class, props, static, env.FNIDX
            rawset( super, module, constructor.class.__index );
            deepCopy( defaultConstructor.class, constructor.class );
            deepCopy( defaultConstructor.props, constructor.props );
            deepCopy( defaultConstructor.static, constructor.static );
            deepCopy( defaultConstructor.env.FNIDX, constructor.env.FNIDX );
        end
    end
    
    return defaultConstructor;
end


local function buildConstructor( constructor )
    local ok, class, classId;
    
    --  create constructor template
    INSPECT_OPTS.udata = constructor.env.FNIDX;
    INSPECT_OPTS_LOCAL.udata = INSPECT_OPTS.udata;
    class = CONSTRUCTOR_TMPL:format(
        inspect( constructor.props, INSPECT_OPTS ),
        inspect( constructor.static, INSPECT_OPTS_LOCAL )
    );
    INSPECT_OPTS.udata = nil;
    INSPECT_OPTS_LOCAL.udata = nil;
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
        rawset( REGISTRY, constructor.id, nil );
    end
    -- add new registry
    classId = getClassId( class );
    constructor.id = classId;
    rawset( REGISTRY, classId, constructor );
    
    return class;
end



-- create build hooks
local function createHooks( newIndex, getIndex, setProperty, super )
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
        -- property register function
        setProperty,
        -- methods of super class
        protectTable( super )
    };
end


local function hasImplicitSelfArg( method )
    local th = coroutine.create( method );
    local checkArgs = function()
        -- enter method
        if debug.getinfo( 2, 'f' ).func == method then
            -- check first argument of method
            local firstArg = debug.getlocal( 2, 1 );
            error( firstArg == 'self' );
        end
    end
    local hasSelf;
    
    -- set hook
    debug.sethook( th, checkArgs, 'c' );
    hasSelf = select( 2, coroutine.resume( th ) );
    -- remove hook
    debug.sethook( th, nil );
    
    return hasSelf;
end


-- class, property, method
local function class( ... )
    -- create constructor
    local constructor = inherits( ... );
    local metatable = constructor.class;
    local method = constructor.class.__index;
    local defaultProps = constructor.props;
    
    -- property register function
    local setProperty = function( props, replace )
        if type( props ) ~= 'table' then
            error( 'property must be type of table' );
        -- merge property table
        elseif not replace then
            mergeCopy( props, defaultProps );
        end
        
        rawset( constructor, 'props', props ); 
    end
    
    -- index hooks(closure)
    local classIndex = {};
    local newIndex = function( tbl, key, val )
        tbl = rawget( classIndex, tostring(tbl) );
        
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
            elseif not hasImplicitSelfArg( val ) then
                error( ('incorrect method declaration: method %q cannot use implicit self variable'):format( key ) );
            end
            rawset( tbl, key, val );
        else
            error( 'unknown table' );
        end
    end
    
    -- return constructor
    local getIndex = function( tbl, key )
        tbl = rawget( classIndex, tostring(tbl) );
        if tbl == metatable then
            if key == 'constructor' then
                return buildConstructor( constructor );
            end
        end
        
        return nil;
    end
    local hooks = createHooks( newIndex, getIndex, setProperty, 
                               constructor.super );
    
    -- create classIndex
    classIndex = {
        [tostring(hooks[1])] = metatable,
        [tostring(hooks[2])] = method
    };
    
    return unpack( hooks );
end


return {
    class = class,
    import = import,
    printRegistry = printRegistry
};

