if exports?
  utils = require('../lib/validoc').utils
  _ = require('underscore')

describe "updateObjectAtPath", ->
  it 'returns the new value if path is empty', ->
    cut = utils.updateObjectAtPath
    actual = cut('x', [], 'y')
    expect(actual).toEqual('y')

  it 'returns the same object, if the update did not modify anything', ->
    cut = utils.updateObjectAtPath
    obj = {x:1}
    actual = cut(obj, ['x'], 1)
    expect(actual).toBe(obj)

  it 'returns a new object with the modification, but does not modify original obj', ->
    cut = utils.updateObjectAtPath
    obj = {x:1}
    actual = cut(obj, ['x'], 2)
    expect(actual).toEqual({x:2})
    expect(obj).toEqual({x:1})
    expect(actual).not.toEqual(obj)