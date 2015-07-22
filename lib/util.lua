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
  
  
  lib/util.lua
  lua-halo
  Created by Masatoshi Teruya on 15/07/08.
  
--]]

local LUA_VERS = tonumber( _VERSION:match( 'Lua (.+)$' ) );
local require = require;
local eval = require('util').eval;
local typeof = require('util.typeof');
local split = require('util.string').split;
local sort = table.sort;
local concat = table.concat;
local getinfo = debug.getinfo;
local getlocal = debug.getlocal;
local getupvalue = debug.getupvalue;
local setupvalue = debug.setupvalue;


local function getPackagePath()
    local i = 1;
    local info, prev;
    
    repeat
        info = getinfo( i, 'nS' );
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


local function sortByLength( a, b )
    return #a > #b;
end


local function getPackageName()
    local src = getPackagePath();
    
    if src then
        local lpath = split( package.path, ';' );
        
        -- sort by length
        sort( lpath, sortByLength );
        -- find filepath
        for _, path in ipairs( lpath ) do
            path = path:gsub( '%-', '%%-' );
            path = path:gsub( '%?.+$', '(.+)[.]lua' );
            path = src:match( path );  
            if path then
                return path:gsub( '/', '.' );
            end
        end
    end
    
    return nil;
end


local function hasImplicitSelfArg( method, info )
    -- for Lua5.2
    if LUA_VERS > 5.1 then
        return getlocal( method, 1 ) == 'self';
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
        
        src = concat( src, '\n' );
        return src:find( '^%s*function%s[^:%s]+%s*:%s*[^%s]+%s*[(]' ) ~= nil;
    end
    
    return false;
end


local function getFunctionId( func )
    return ('%s'):format( tostring(func) ):gsub( '^function: 0x0*', '' );
end


local function getUpvalues( fn )
    local upv = {};
    local i = 1;
    local k, v = getupvalue( fn, i );
    local env;
    
    while k do
        if env == nil and k == '_ENV' then
            env = v;
        end
        upv[i] = { key = k, val = v };
        i = i + 1;
        k, v = getupvalue( fn, i );
    end
    
    return upv, env;
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


local function cloneFunction( fn )
    local upv, env = getEnv( fn );
    
    fn = string.dump( fn );
    fn = assert( eval( fn, env ) );
    -- copy to upvalues
    for i, kv in ipairs( upv ) do
        setupvalue( fn, i, kv.val );
    end
    
    return fn, env;
end


return {
    getPackageName = getPackageName,
    hasImplicitSelfArg = hasImplicitSelfArg,
    getFunctionId = getFunctionId,
    mergeRight = mergeRight,
    mergeLeft = mergeLeft,
    cloneFunction = cloneFunction,
};

