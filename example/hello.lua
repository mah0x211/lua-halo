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
  
  
  example/hello.lua
  lua-halo
  Created by Masatoshi Teruya on 14/05/28.
  
--]]

local halo = require('halo');
-- create class
local Class = halo.class.Hello;

-- MARK: Define Static
Class.property {
    hello_version = 0.1
};

function Class.__call()
    print( 'call static' );
end

function Class.name()
    print( 'hello' );
end


-- MARK: Define Instance
Class:property {
    -- public property
    public = {
        hello = 'hello'
    }
};

function Class:__gc()
    print( 'gc' );
end

-- Override Initializer
function Class:init( ... )
    print( 'init hello', ... );
    -- initializer must be returned self
    return self;
end

function Class:say( ... )
    print( 'say', self.hello, ... );
end


function Class:say2( ... )
    print( 'say2', self.hello, ... );
end


-- MARK: Export Class Constructor
return Class.exports;


