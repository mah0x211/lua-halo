lua-halo
==========

Simple OOP Library For Lua

## Installation

```sh
luarocks install --from=http://mah0x211.github.io/rocks/ halo
```

## Create Class

### Class, Method, Property, Super = halo.class( [baseClass [, ...]] )

** Returns **

1. Class: class table.
2. Method: method table.
3. Property: property register function.
4. Super: method table of base classes.

** Example **

```lua
local halo = require('halo');
-- create class
local Class, Method, Property = halo.class();
```

## Define Class Definition

### Metamethods

```lua
function Class:__gc()
    print( 'gc' );
end
```

### Class Methods

```lua
function Class:name()
    print( 'hello' );
end
```

### Class Variables

```lua
Class.version = 0.1;
```

### Properties (Instance Variables)

```lua
Property({
    hello = 'hello'
} [, replaceInheritedVariables:boolean] );
```

### Override Initializer

```lua
function Method:init( ... )
    print( 'init hello', ... );
end
```

### Instance Methods
```lua
function Method:say( ... )
    print( 'say', self.hello, ... );
end
```

### Export Class Constructor
```lua
return Class.constructor;
```


### Using Halo-Class Module

you should require halo module before using the halo-class modules.

```lua
require('halo');
local hello = require('hello');

local helloObj = hello.new( 1, 2, 3 );
```

## Example Usage

**example/hello.lua**

```lua:hello.lua
--[[
  example/hello.lua
  lua-halo
  Created by Masatoshi Teruya on 14/05/28.
--]]

local halo = require('halo');
-- create class
local Class, Method, Property = halo.class();

--[[
    MARK: Define Metamethods
--]]
function Class:__gc()
    print( 'gc' );
end


--[[
    MARK: Define Class Methods
--]]
function Class:name()
    print( 'hello' );
end

--[[
    MARK: Define Class Variables
--]]
Class.version = 0.1;


--[[
    MARK: Define Properties
--]]
Property({
    hello = 'hello'
});


--[[
    MARK: Override Initializer
--]]
function Method:init( ... )
    print( 'init hello', ... );
end


--[[
    MARK: Define Instance Methods
--]]
function Method:say( ... )
    print( 'say', self.hello, ... );
end

function Method:say2( ... )
    print( 'say2', self.hello, ... );
end


--[[
    MARK: Export Class Constructor
--]]
return Class.constructor;

```

**example/world.lua**

```lua:world.lua
--[[
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
    Super.hello.init( self, ... );
    print( 'init world', bases, ... );
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
```

**example/example.lua**

```lua:example.lua
--[[
  example/example.lua
  lua-halo
  Created by Masatoshi Teruya on 14/05/28.
  
--]]
-- require halo module before using the halo-class modules.
local halo = require('halo');
local hello = require('hello');
local world = require('world');


print( '\nCREATE hello INSTANCE ----------------------------------------------' );
local helloObj = hello.new( 1, 2, 3 );
print( '\nCREATE world INSTANCE ----------------------------------------------' );
local worldObj = world.new( 4, 5, 6 );

print( '\nCALL hello INSTANCE METHOD -----------------------------------------' );
helloObj:say( 1, 2, 3 );
helloObj:say2( 4, 5, 6 );

print( '\nCALL world INSTANCE METHOD -----------------------------------------' );
worldObj:say( 7, 8, 9 );
worldObj:say2( 10, 11, 12 );


print( '\nCHECK COMPARE INSTANCE METHOD -----------------------------------' );
print( 
    'helloObj.say == worldObj.say\n',
    ('= %s == %s\n'):format( helloObj.say, worldObj.say ), 
    ('= %s\n'):format( helloObj.say == worldObj.say )
);
print( 
    'helloObj.say2 == worldObj.say2\n',
    ('= %s == %s\n'):format( helloObj.say2, worldObj.say2 ), 
    ('= %s'):format( helloObj.say2 == worldObj.say2 )
);

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
```

**output**

```
CREATE hello INSTANCE ----------------------------------------------
init hello	table: 0x000459c8	1	2	3

CREATE world INSTANCE ----------------------------------------------
init hello	table: 0x0005bb20	4	5	6
init world	table: 0x0005bb20	4	5	6

CALL hello INSTANCE METHOD -----------------------------------------
say	hello	1	2	3
say2	hello	4	5	6

CALL world INSTANCE METHOD -----------------------------------------
say	hello	world	7	8	9
say2	hello	10	11	12

CHECK COMPARE INSTANCE METHOD -----------------------------------
helloObj.say == worldObj.say
	= function: 0x0005d120 == function: 0x00060248
	= false

helloObj.say2 == worldObj.say2
	= function: 0x0005d140 == function: 0x0005d140
	= true

CHECK INSTANCEOF -------------------------------------------------
halo.instanceof( helloObj, hello )	true
halo.instanceof( helloObj, world )	false
halo.instanceof( worldObj, world )	true
halo.instanceof( worldObj, hello )	false
```
