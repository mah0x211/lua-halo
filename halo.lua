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
local inspect = require('util').inspect;
local require = require;
local REGISTRY = {};
local METHOD_TMPL = [==[setmetatable(%s, %s)]==];
local CONSTRUCTOR_TMPL = [==[
local function Constructor(...)
    local self = setmetatable( %s, %s );
    
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
    error( 'attempt to change the super table', 2 );
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
        class = {},
        methods = {
            -- initializer
            init = init
        },
        methodsmt = {},
        props = {},
        static = {},
        -- method table of super classes
        super = {},
        -- set constructor environments
        env = {
            setmetatable = setmetatable,
            FNIDX = {}
        }
    };
    local inheritance = {};
    local super = defaultConstructor.super;
    local module, constructor, i, _;
    
    -- loading modules
    for i, module in ipairs({...}) do
        if not rawget( inheritance, module ) then
            constructor = getClassConstructor( module );
            -- this class is not halo class
            if not constructor then
                error( ('inherit: %q is not halo class'):format( module ), 3 );
            end
            
            rawset( inheritance, module, true );
            -- copy super, class, props, static, env.FNIDX
            rawset( super, module, constructor.methods );
            deepCopy( defaultConstructor.class, constructor.class );
            deepCopy( defaultConstructor.methods, constructor.methods );
            deepCopy( defaultConstructor.methodsmt, constructor.methodsmt );
            deepCopy( defaultConstructor.props, constructor.props );
            deepCopy( defaultConstructor.static, constructor.static );
            deepCopy( defaultConstructor.env.FNIDX, constructor.env.FNIDX );
        end
    end
    
    return defaultConstructor;
end


local function makeTemplate( constructor )
    local tmpl, methods;
    
    --  create constructor template
    INSPECT_OPTS.padding = 4;
    INSPECT_OPTS.udata = constructor.env.FNIDX;
    INSPECT_OPTS_LOCAL.udata = INSPECT_OPTS.udata;
    -- render constructor
    constructor.class.__index = 'METHOD_TMPL';
    tmpl = CONSTRUCTOR_TMPL:format(
        inspect( constructor.props, INSPECT_OPTS ),
        inspect( constructor.class, INSPECT_OPTS ),
        inspect( constructor.static, INSPECT_OPTS_LOCAL )
    );
    -- render method table
    INSPECT_OPTS.padding = 8;
    methods = METHOD_TMPL:format(
        inspect( constructor.methods, INSPECT_OPTS ),
        inspect( constructor.methodsmt, INSPECT_OPTS )
    );
    INSPECT_OPTS.udata = nil;
    INSPECT_OPTS_LOCAL.udata = nil;
    
    -- insert method table
    return tmpl:gsub( '"METHOD_TMPL"', methods );
end


local function buildConstructor( constructor )
    local tmpl = makeTemplate( constructor );
    local ok, class, classId;
    
    -- create constructor
    -- for Lua5.2
    if LUA_VERS > 5.1 then
        ok, class = pcall( load( tmpl, nil, 't', constructor.env ) );
    -- for Lua5.1
    else
        class = loadstring( tmpl );
        setfenv( class, constructor.env );
        ok, class = pcall( class );
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


local function hasImplicitSelfArg( checklist, method )
    local addr = tostring( method );

    -- for Lua5.2
    if LUA_VERS > 5.1 then
        if checklist[addr] == nil then
            checklist[addr] = debug.getlocal( method, 1 ) == 'self';
        end
    -- for Lua5.1
    else
        local info = debug.getinfo( method );
        
        if info.what == 'Lua' then
            local head, tail = info.linedefined, info.lastlinedefined;
            local lineno = 0;
            local src = {};
            local line;
            
            for line in io.lines( info.source:sub( 2 ) ) do
                lineno = lineno + 1;
                if lineno > tail then
                    break;
                elseif lineno >= head then
                    rawset( src, #src + 1, line );
                end
            end
            
            src = table.concat( src, '\n' );
            checklist[addr] = src:find( '^%s*function%s[^:]+:' ) ~= nil;
        end
    end
    
    return checklist[addr];
end


local function checkMethodDecl( checklist, key, val )
    if type( val ) ~= 'function' then
        error( 'method must be type of function', 3 );
    elseif not hasImplicitSelfArg( checklist, val ) then
        error( ([[
incorrect method declaration: method %q cannot use implicit self variable
]]):format( key ), 3 );
    end
end


-- class, property, method
local function class( ... )
    -- create constructor
    local constructor = inherits( ... );
    local metatable = constructor.class;
    local methods = constructor.methods;
    local methodsmt = constructor.methodsmt;
    local defaultProps = constructor.props;
    local checklist = {};
    
    -- property register function
    local setProperty = function( props, replace )
        if type( props ) ~= 'table' then
            error( 'property must be type of table', 2 );
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
        
        if type( key ) ~= 'string' then
            error( 'field name must be type of string', 2 );
        -- metamethod and class method
        elseif tbl == metatable then
            if key == 'constructor' then
                error( ('%q field changes are disallowed'):format( key ), 2 );
            -- metamethod
            elseif key:find( '^__*' ) then
                if val ~= nil then
                    checkMethodDecl( checklist, key, val );
                end
                
                -- set __index method into method metatable
                if key == '__index' then
                    rawset( methodsmt, key, val );
                else
                    rawset( tbl, key, val );
                end
            -- class method or class variable
            else
                rawset( constructor.static, key, val );
            end
        -- instance method
        elseif tbl == methods then
            if key == 'init' and type( val ) ~= 'function' then
                error( ('%q method must be type of function'):format( key ), 2 );
            elseif val ~= nil then
                checkMethodDecl( checklist, key, val );
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
        [tostring(hooks[2])] = methods
    };
    
    return unpack( hooks );
end


return {
    class = class,
    import = import,
    printRegistry = printRegistry
};

