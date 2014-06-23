lua-halo
==========

Simple OOP Library For Lua

## Installation

```sh
luarocks install --from=http://mah0x211.github.io/rocks/ halo
```

## Dependencies

- lua-util https://github.com/mah0x211/lua-util


## Create Class

### Class = halo.class.ClassName;
( [baseClass [, ...]] )

** Returns **

1. Class: class specifier.

** Example **

```lua
local halo = require('halo');
-- create class
local Class = halo.class.ClassName;
```

## Class Property/Method/Metamethod Definition

### Property

```lua
Class:property {
    -- public variable
    public = {
        hello = 'hello'
    },
    -- protected variable
    protected = {
        world = 'world'
    }
};
```

### Method
```lua
function Class:say( ... )
    print( 'say', self.hello, ... );
end
```

### Metamethod

```lua
function Class:__gc()
    print( 'gc' );
end
```

### Override Initializer

```lua
function Class:init( ... )
    print( 'init hello', ... );
    -- initializer must be returned self
    return self;
end
```


### Export Class Constructor
```lua
return Class.exports;
```


## Static Property/Method/Metamethod Definition

### Property

```lua
Class.property {
    version = 0.1
};
```

### Method

```lua
function Class.name()
    print( 'hello' );
end
```

### Metamethod

```lua
function Class.__gc()
    print( 'gc' );
end
```

### Using Halo-Class Module

```lua
local hello = require('hello');
local helloObj = hello.new( 1, 2, 3 );
```

## Example Usage

**example/hello.lua**

```lua
--[[
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
```

**example/world.lua**

```lua
--[[
  example/world.lua
  lua-halo
  Created by Masatoshi Teruya on 14/05/28.
--]]

local halo = require('halo');
-- create class
local Class = halo.class.World;

-- MARK: Inheritance
Class.inherits {
    -- inherit hello class
    'hello.Hello',
    except = {
        instance = {
            '__gc'
        }
    }
};

-- MARK: Define Static
Class.property {
    version = 0.2
};

function Class.name()
    print( 'world' );
end


-- MARK: Define Instance
Class:property {
    -- protected property
    protected = {
        world = 'world'
    }
};

-- Override Initializer
function Class:init( ... )
    -- call base class method
    base['hello.Hello'].init( self, ... );
    print( 'init world', ... );
    
    return self;
end

function Class:say( ... )
    print(
        'say', self.hello, 
        -- access to protected property
        protected(self).world, 
        ... 
    );
end


-- MARK: Export Class Constructor
return Class.exports;
```

**example/example.lua**

```lua
--[[
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
```

**output**

```
CREATE hello INSTANCE --------------------------------------------
init hello	1	2	3

CREATE world INSTANCE --------------------------------------------
init hello	4	5	6
init world	4	5	6

CALL hello INSTANCE METHOD ---------------------------------------
say	hello	1	2	3
say2	hello	4	5	6

CALL world INSTANCE METHOD ---------------------------------------
say	hello	world	7	8	9
say2	hello	10	11	12

CHECK INSTANCEOF -------------------------------------------------
halo.instanceof( helloObj, hello )	true
halo.instanceof( helloObj, world )	false
halo.instanceof( worldObj, world )	true
halo.instanceof( worldObj, hello )	false
```
