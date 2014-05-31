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
  
  
  example/world.lua
  lua-halo
  Created by Masatoshi Teruya on 14/05/28.
  
--]]

local halo = require('halo');
-- create class
-- inherit hello class
local Class, Method, Property, Super = halo.class( 'hello' );

--[[
    MARK: Define Class Methods
--]]
function Class:name()
    print( 'world' );
end

--[[
    MARK: Define Class Variables
--]]
Class.version = 0.2;


--[[
    MARK: Define Properties
--]]
Property({
    world = 'world'
});


--[[
    MARK: Override Initializer
--]]
function Method:init( ... )
    Super.hello.init( self, ...);
    print( 'init world', ... );
end

--[[
    MARK: Define Instance Methods
--]]
function Method:say( ... )
    print( 'say', self.hello, self.world, ... );
end


--[[
    MARK: Export Class Constructor
--]]
return Class.constructor;

