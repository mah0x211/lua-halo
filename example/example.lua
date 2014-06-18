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
  
  
  example/example.lua
  lua-halo
  Created by Masatoshi Teruya on 14/05/28.
  
--]]
local halo = require('halo');
local hello = require('hello');
local world = require('world');


print( '\nCREATE hello INSTANCE --------------------------------------------' );
local helloObj = hello.new( 1, 2, 3 );
print( '\nCREATE world INSTANCE --------------------------------------------' );
local worldObj = world.new( 4, 5, 6 );

print( '\nCALL hello INSTANCE METHOD ---------------------------------------' );
helloObj:say( 1, 2, 3 );
helloObj:say2( 4, 5, 6 );

print( '\nCALL world INSTANCE METHOD ---------------------------------------' );
worldObj:say( 7, 8, 9 );
worldObj:say2( 10, 11, 12 );


print( '\nCHECK INSTANCEOF -------------------------------------------------' );
print( 
    'halo.instanceof( helloObj, hello )', halo.instanceof( helloObj, hello )
);
print(
    'halo.instanceof( helloObj, world )', halo.instanceof( helloObj, world )
);
print(
    'halo.instanceof( worldObj, world )', halo.instanceof( worldObj, world )
);
print(
    'halo.instanceof( worldObj, hello )', halo.instanceof( worldObj, hello )
);

