lua-schema
==========

A simple package to check LUA-data against schemata. The package is written
entirely in Lua (5.2) and has no further dependencies. It is designed to be
easily extensible. 

The problem tackled by this package is the following: Suppose your program is
reading data via Lua. Verifying that the data fulfills the requirements of your
program is tedious; Lua's lack of types requires you to write repetitive code
to verify the input data.

The solution proposed by this package are *schemata*: You specify a schema for
the data and the program automatically verifies the data for you.


Installation
------------
Put ```schema.lua``` somewhere where your program can find it. Then use

    local schema = require "schema.lua"


Example
-------
We read a bunch of tables, each of them looks like this:
    
    user = {
        id        = 12, -- id is a number
        usertype  = "admin", -- one of 'admin', 'moderator', 'user'
        nicknames = { "Nick1", "Nick2" }, -- nicknames used by this user
        rights    = { 4, 1, 7} -- table of fixed length of types
    }

A schema describing such a table would be

    local s = require "schema.lua"

    rights = s.AllOf(s.NumberFrom(0, 7), s.Integer)

    userSchema = s.Record {
        id        = s.Number,
        usertype  = s.OneOf("admin", "moderator", "user"),
        nicknames = s.Collection(s.String),
        rights    = s.Tuple(rights, rights, rights) 
    }

This schema can now be used to check the data:

    local err = s.CheckSchema(user, userSchema)

    -- 'err' is nil if no error occured
    if err then
        print(s.FormatOutput(err))
    end


Usage
-----
Specify a schema for your data using the built-in schemata or by writing custom
schemata. A schema is either a function or a non-function value. 
The program takes an *object* to be checked and a *schema*. If the schema is a
non-function value, the program uses Lua's comparison operator to compare the
object to the schema. If the schema is a function, the program returns the
result of the function applied to the object and the path of the object in the
main-object to check. Schema functions always return list of errors.

The main function to get things going is ```schema.CheckSchema(obj, schema)```.
It returns nil iff the data matches the schema. Otherwise it returns a list of
errors (which in turn may contain suberrors). Use 
```schema.FormatOutput(output)``` on a non-nil result of 
```schema.CheckSchema``` to get a string describing all errors (or just use
```tostring``` on the result).

The package comes with a set of builtin schemata (see below). It is very easy
to extend the package with additional schemata (see 'Custom Schemata' below).


Builtin Schemata
----------------
The schemata built into the package are (mostly) designed to check *local*
properties of the data (*context free* properties). While it is possible to
write custom schemata to handle context sensitive data (such as uniqueness of
certain values), the schemata shipping with the library feature only a single
context sensitive schema ('Case', see below).

All non-function values are schemata.
The following schemata are built into the package (sorted alphabetically):

* **AllOf(...)**

  Takes a list of schemata and accepts any object that is accepted by all of
  the schemata. Example:

      local exampleSchema = schema.AllOf(schema.NonNegativeNumber, schema.Integer)
      local posExample = 3
      local negExample = 2.4
      -- Invalid value: '<val>' must be an integral number
      print(schema.CheckSchema(negExample, exampleSchema))
      local negExample2 = -2.4
      -- Invalid value: '<val>' must be >= 0
      -- Invalid value: '<val>' must be an integral number
      print(schema.CheckSchema(negExample2, exampleSchema))

* **Any**

  Matches anything. Example:
      
      local exampleData = { "test" }
      -- err is always nil
      local err = schema.CheckSchema(exampleData, schema.Any)

* **Boolean**

  Matches booleans. Example:

      local posExample = true
      local negExample = { true }
      -- Type mismatch: '<val>' should be boolean, is table
      print(chema.CheckSchema(negExample, schema.Boolean))

* **Case(path, ...)**

  Takes a *relative path* and a list of entries of the form ```{c, s}```,
  whereby ```c``` (condition) and ```s``` (consequence) are both schemata.
  It then navigates to the value denoted by the relative path and checks it
  against every condition schema. If the condition schema matches, then it
  tries to apply the consequence schema to the value.

  The relative path is either a non-table value or a path constructed using
  ```schema.Path```. In such paths, '..' denotes the parent of a value. This
  parent must be part of the object to be checked.
  If a value ```v``` is given instead of a path, the program constructs a path
  as in ```schema.Path("..", v)```.
  Example:

      local exampleSchema = schema.Record {
        kind   = schema.OneOf("user", "admin"),
        rights = schema.Case("kind", {"user", "000"}, {"admin", "777"})
      }
      local posExample = {
        kind   = "user",
        rights = "000"
      }
      
      local negExample = {
        kind = "user",
        rights = "777"
      }
      -- Case failed: Condition 1 of 'rights' holds but the consequence does not
      --   Invalid value: rights should be 000
      print(schema.CheckSchema(negExample, exampleSchema))
      local negExample2 = {
        kind  = "test", -- invalid kind!
        rights = "777" 
      }

      -- Case failed: No condition on 'rights' holds
      -- No suitable alternative: No schema matches 'kind'
      print(schema.CheckSchema(negExample2, exampleSchema))

* **Collection(valSchema)**

  Alias for ```Map(Any,valSchema)```: Takes a schema and matches all tables
  which have values matching the given schema. The keys of the table are
  ignored. Also accepts the empty table. Example:

      local exampleSchema = schema.Collection(schema.Boolean)
      local posExample = {}
      local posExample2 = { test = true, false, false }
      
      local negExample = "test"
      -- Type mismatch: '<val>' should be a map (table), is string
      print(schema.CheckSchema(negExample, exampleSchema))

      local negExample2 = { "true", test = 1, false }
      -- Type mismatch: '1' should be boolean, is string
      -- Type mismatch: 'test' should be boolean, is number
      print(schema.CheckSchema(negExample2, exampleSchema))


* **Function**

  Matches functions. Example:

      local posExample = table.concat

      local negExample = "test"
      -- Type mismatch: '<val>' should be function, is string
      print(schema.CheckSchema(negExample, schema.Function))

* **Integer**

  Matches integers. Example:

      local posExample = 42

      local negExample = "test"
      -- Type mismatch: '<val>' should be number, is string
      print(schema.CheckSchema(negExample, schema.Integer))

      local negExample2 = 42.1
      -- Invalid value: '<val>' must be an integral number
      print(schema.CheckSchema(negExample2, schema.Integer))

* **Map(keySchema, valSchema)**

  Matches all tables whose keys match the ```keySchema``` and whose values
  match the ```valSchema```. Example:

      local exampleSchema = schema.Map(schema.Integer, true)
      local posExample = { [1] = true, [42] = true }

      local negExample = { test = true }
      -- Invalid map key
      --   Type mismatch: 'test' should be number, is string
      print(schema.CheckSchema(negExample, exampleSchema))

* **Nil**

  Matches ```nil```. Note that you could just as well use the value ```nil```
  as a schema in *most* situations. If an argument list is used, you should
  prefer ```Nil``` to ```nil``` due to the way that Lua deals with ```nil```
  values in tables. Example:

      local posExample = nil

      local negExample = 1
      -- Type mismatch: '<val>' should be nil, is number
      print(schema.CheckSchema(negExample, schema.Nil))

* **NonNegativeNumber**

  Matches all non-negative numbers (i.e, number >= 0). Example:

      local posExample = 42.3

      local negExample = -14
      -- Invalid value: '<val>' must be >= 0
      print(schema.CheckSchema(negExample, schema.NonNegativeNumber))

* **Nothing**

  Does not match anything. Always returns an error.

      local negExample = { "test" }
      -- Failure: '<val>' will always fail.
      print(schema.CheckSchema(negExample, schema.Nothing))

* **Number**
  
  Matches all numbers.

      local posExample = 42

      local negExample = "test"
      -- Type mismatch: '<val>' should be number, is string
      print(schema.CheckSchema(negExample, schema.Integer))

* **NumberFrom(lower, upper)**
  
  Matches all numbers in the interval [lower, upper].

      local exampleSchema = schema.NumberFrom(0, 42)
      local posExample = 42

      local negExample = -1
      -- Invalid value: '<val>' must be between 0 and 42
      print(schema.CheckSchema(negExample, exampleSchema))

* **OneOf(...)**
  
  Takes a list of schemata and accepts any object that is accepted by at least
  one of the schemata.

      local exampleSchema = schema.OneOf(schema.String, schema.Number)
      local posExample = 1
      local posExample2 = "test"

      local negExample = true
      -- No suitable alternative: No schema matches '<val>'
      print(schema.CheckSchema(negExample, exampleSchema))

* **Optional(s)**
   
  Alias for ```OneOf(s, Nil)```. Represents optional values.
  Example:

      local exampleSchema = schema.Optional(schema.Integer)
      local posExample = 1
      local posExample2 = nil

      local negExample = "test"
      -- No suitable alternative: No schema matches '<val>'
      print(schema.CheckSchema(negExample, exampleSchema))

* **PositiveNumber**

  Matches all positive numbers (i.e, number > 0). Example:

      local posExample = 42.3

      local negExample = -14
      -- Invalid value: '<val>' must be >= 0
      print(schema.CheckSchema(negExample, schema.PositiveNumber))

* **Record(tableSchema, additionalValues = false)**
  
  Takes a table schema. The table schema consists of keys (strings only) and 
  schemata for the corresponding values. If the object contains additional
  values to those mentioned in the schema, the schema fails. This behavior can
  be changed by setting the second argument to ```true```.
  Example:

      local exampleSchema = schema.Record {
        data = schema.String,
        data2 = schema.Record {
          test = schema.Number
        }
      }
      local posExample = {
        data = "",
        data2 = {
          test = 15
        }
      }

      local negExample = {
        [1] = "",
        data2 = {
          test = "12"
        }
      }
      -- Type mismatch: 'data' should be string, is nil
      -- Type mismatch: 'data2.test' should be number, is string
      -- Invalid key: '1' must be of type 'string'
      -- Superfluous value: '1' does not appear in the record schema
      print(schema.CheckSchema(negExample, exampleSchema))

* **String**

  Matches strings. Example:

      local posExample = "test"

      local negExample = 42
      -- Type mismatch: '<val>' should be string, is number
      print(schema.CheckSchema(negExample, schema.String))

* **Table**

  Matches tables (as in: everything that is of type table). Example:

      local posExample = {}
      local posExample2 = { test = true }

      local negExample = "42"
      -- Type mismatch: '<val>' should be table, is string
      print(schema.CheckSchema(negExample, schema.Table))

* **Test(fn, [msg])**

  Runs an arbitrary test function on the value. This is useful for quickly creating
  custom validations. Example:

      local negExample = {
        plugin = "invalid.module"
      }

      -- Invalid value: '<plugin>': not an existing module
      print(schema.CheckSchema(negExample, schema.Test(function(v) return pcall(require, v) end, "not an existing module")))

* **Tuple(...)**

  Takes schemata and matches against a tuple of those schemata in the order
  passed to the constructor. Example:

      local exampleSchema = schema.Tuple(schema.Number, schema.String)
      local posExample = { 1, "42" }

      local negExample = { "42", 1}
      -- Type mismatch: '1' should be number, is string
      -- Type mismatch: '2' should be string, is number
      print(schema.CheckSchema(negExample, exampleSchema))
      
      local negExample2 = {1, "42", 14}
      -- Invalid length: '<val> should have exactly 2 elements
      print(schema.CheckSchema(negExample, exampleSchema))

* **UserData**
  
  Matches user data.


Custom Schemata
---------------
Adding custom schemata is straight-forward. We will start with an example.
Suppose we want to have a schema for even integers. We will design a function
that matches just those:

    -- All schemata get the object to check and a 'path' variable as arguments.
    --   - obj is what we want to check
    --   - path is the path to obj from the main object to check
    function EvenInteger(obj, path)
        -- first check that the obj is an integer.
        local err = schema.Integer(obj, path)
        -- got an error? propagate it.
        if err then return err end
        if obj % 2 ~= 0 then
            return schema.Error("Invalid value: "..path.." must be even", path)
        end
        return nil
    end

Alternatively, you can use `schema.Test`:

    EvenInteger = schema.AllOf(
                     schema.Integer,
                     schema.Test(function(obj) return obj % 2 == 0 end, "must be even")
                  )

There are a few things to note:

* schema.Error(msg, path, suberrors)

  Takes a message, the current path and a list of errors. Returns a list of
  errors. If you want to aggregate errors, use ```append```:

      local err = schema.Integer(obj, path)
      -- add another error
      err:append(schema.Error(...))

* The ```path``` argument is not a string, but a table. Use
  ```path:push(key)``` add a key to the path; ```path:pop()``` to remove the
  last key. Note that ```path:push``` does *not* return a new path but modifies
  the original path. Your function is expected to get ```path``` back into its
  original state when it returns. Use ```path:copy()``` to get a copy of the
  path. ```path:getBase()``` returns the base object (i.e. the main object to
  be checked). ```path:target()``` returns the value the path points to
  relative to its base object..