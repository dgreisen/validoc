###
the base Field class and most of the core fields.
###

if exports?
  utils = require "./utils"
  validators = require "./Validators"
  _ = require "underscore"
else if window?
  utils = window.utils
  validators = window.validators
  _ = window._

ValidationError = utils.ValidationError

class Field
  ###
  Baseclass for all fields. Fields are defined by a schema. 
  You can override attributes and methods within the schema. 
  For example:

      var simpleSchema = { name: "firstField"
                         , field: "Field"
                         , required: false
                         };

  will create a basic field that is not required.
  This is not particularly useful.
  But we can create useful fields using subclasses of Field:

      var pwSchema = { name: "badPasswordField"
                     , field: "CharField"
                     , maxLength: 8
                     , minLength: 4
                     , widget: "Widgets.PasswordWidget"
                     };

  Now we have created a very insecure password field schema.
  We have overridden the Charfield's default widget with a password widget.

  We create a Field instance from a schema by calling:

      simpleField = validoc.genField(simpleSchema);

  We create a ReactJS widget component from a schema by calling:

      simpleWidget = validoc.genWidget(simpleSchema);

  The following attributes can be specified in the schema.
  Any defaults can be overridden by subclasses:
    
    * `field`: the field type (e.g. CharField, ContainerField) (required)
    * `name`: the name/identifier for this field (required)
    * `widget`: widget constructor hash or string name
       (e.g. { widget: "widget.Widget"}, or simply "widget.Widget")
       (default: depends on Field type)
    * `required`: whether the current field is required (default: true)
    * `default`: the default value of the field.
      If the value is undefined, the value will be set to the default value.


  When you call genField or genWidget,
  you can specify `value` and `initialValue` as optional 2nd and 3rd 
  arguments, respectively.

    * `value`: the current value of the field
    * `initialValue`: the initial value of the field (useful for validation)

  The following attributes can also technically be specified in the schema,
  but in practice, the should only have to be modified by subclasses:

    * `errorMessages`: hash of error message codes and keys.
      You can override any error message by setting a new message for the code.
    * `validators`: array of validators;
      If overriding a parent class, you must include all ancestor validators
    * `listeners`: hash of listeners of one of the following forms:
      * `'event': (inSender, inEvent) ->`
      * `'event': "handlerMethod"`
      * `'*': "handlerMethod"`
      wildcard will handle all incoming events

  You are probably doing something wrong if you access an attribute
  that starts with an underscore. You should **never** directly modify
  any attribute that starts with an underscore.
  ###

  name: undefined
  # whether the current field is required
  required: true
  # the current value of the field
  # kind definition for widget to display (eg { kind: "widget.Widget"}, or simply the string name of the widget kind)
  widget: "widgets.Widget",

  ###
  hash of listeners of the form
      * `'event': (inSender, inEvent) ->`
      * `'event': "handlerMethod"`
      * `'*': "handlerMethod"`
  wildcard will handle all incoming events
  ###
  listeners: {}
  # list of validators; If overriding a parent class, you must include all parent class validators
  validators: [],
  # hash of error messages; If overriding a parent class, you must include all parent class errorMessages
  errorMessages:
    required: utils._i('This field is required.')

  # the cleaned value accessed via `getClean()`;
  # this will be a javascript value (such as a DateTime) 
  # that should be used for any calculations, etc.
  # Use the toJSON() method to get a version appropriate for serialization.
  _clean: undefined,
  # a list of errors for this field.
  _errors: [],
  # parent field, set by parent
  _parent: undefined
  # the name/identifier for this field
  value: undefined
  # the initial value of the field (for validation)
  initial: undefined
  # the default value of the field. if the set value is undefined, the value will changed to the default value
  default: undefined
  constructor: (opts) ->
    # save an unadulterated copy of opts in @opts
    opts ?= {}
    @opts = _.clone(opts)
    # compile inherited attributes
    @errorMessages = @_walkProto("errorMessages")
    if opts.errorMessages 
      _.extend(@errorMessages, opts.errorMessages)
      delete opts.errorMessages    
    @listeners = {}
    # set initial values; 
    opts.value ?= opts.initial
    opts.initial ?= opts.value
    _.extend(this, opts)
    delete @value
    # add this field to its parent's list of subfields (have to do it 
    # here so it can be found when it emits events during construction)
    if @_parent?._fields? then @_parent._fields.push(this)
    # all fields were sharing the same validators list
    @validators = _.clone(@validators)
    # announce that a new field has been created
    @emit("onFieldAdd", {schema: @opts, value: opts.value})
    if @setSchema
      schema = _.clone(@schema)
      delete @schema
      @setSchema(schema, {value: opts.value})
    #set initial value
    @setValue(opts.value)
  _walkProto: (attr) ->
    ### walks the prototype chain collecting all the values off attr and combining them in one. ###
    sup = @constructor.__super__
    if sup?
      return _.extend(_.clone(sup._walkProto(attr)), @[attr])
    else
      return this[attr]
  getErrors: () ->
    ### get the errors for this field. returns null if no errors. ###
    @isValid()
    return if @_errors.length then @_errors else null
  toJavascript: (value) ->
    ###
    First function called in validation process.<br />
    this function converts the raw value to javascript. `value` is the raw value from
    `@getValue()`. The function returns the value in the proper javascript format,<br />
    this function should be able to convert from any type that a widget might supply to the type needed for validation
    ###
    return value
  # for keeping track of whether to emit the validChanged event
  _valid: false
  # whether we need to run the full validation process
  _hasChanged: true
  validate: (value) ->
    ###
    Second function called in validation process.<br />
    Any custom validation logic should be placed here. receives the input, `value`, from `toJavascript`'s output.
    return the value with any modifications. When validation fails, throw a utils.ValidationError. with a 
    default error message, a unique error code, and any attributes for string interpolation of the error message
    be sure to call `@super <br />
    default action is to check if the field is required
    ###
    if (validators.isEmpty(value) && @required)
      throw ValidationError(@errorMessages.required, "required")
    return value
  runValidators: (value) ->
    ###
    Third function called in validation process.<br />
    You should not have to override this function. simply add validators to @validators.
    ###
    if (validators.isEmpty(value)) then return
    for v in @validators
      @_catchErrors(v, value)
    return value;
  isValid: (opts) ->
    ### primary validation function<br />
    calls all other validation subfunctions and emits a `validChanged` event if the valid state has changed.
    returns `true` or `false`
    only precesses the full validation if hasChanged is true, which is only true if something has changed since the last call to isValid()
    emits the `validChanged` event if the valid state has changed.
    ###
    if not @_hasChanged then return @_valid
    # reset the errors array
    oldErrors = _.clone(@_errors)
    @_errors = []
    # call the various validators
    value = @getValue()
    value = @_catchErrors(@toJavascript, value)
    value = @_catchErrors(@validate, value) if (!@_errors.length)
    value = @runValidators(value) if (!@_errors.length)
    valid = !@_errors.length
    @_clean = if valid then value else undefined
    if valid != @_valid or not valid and not _.isEqual(oldErrors, @_errors)
      @emit("onValidChanged", valid: valid, errors: @_errors)
      @_valid = valid
    @_hasChanged = false
    return valid
  _catchErrors: (fn, value) ->
    ### helper function for running an arbitrary function, capturing errors and placing in error array ###
    try
      if fn instanceof Function
        value = fn.call(this, value)
      else
        value = fn.validate(value)
    catch e
      message = if @errorMessages[e.code]? then @errorMessages[e.code] else e.message
      message = utils.interpolate(message, e.params) if e.params?
      @_errors.push(message)
    return value

  getClean: (opts) ->
    ###
    return the fild's cleaned data if there are no errors. throws an error if there are validation errors.
    you will likely have to override this in Field subclasses
    ###
    valid = @isValid(opts)
    if not valid
      throw @_errors
    return @_clean
  toJSON: (opts) ->
    ###
    return the field's cleaned data in serializable form if there are no errors. throws an error if there are validation errors.  
    you might have to override this in Field subclasses.
    ###
    return @getClean(opts)
  setRequired: (val) ->
    if val != @required
      @_hasChanged = true
      @required = val
      @emit("onRequiredChanged", {required: @required})
  setValue: (val, opts) ->
    ### You should not have to override this in Field subclasses ###
    if val == undefined then val = @default
    if val != @value
      @_hasChanged = true
      origValue = @value
      @value = val;
      @emit("onValueChanged", value: @getValue(), original: origValue)
  getValue: () ->
    ### You should not have to override this in Field subclasses ###
    return @value;
  getPath: () ->
    ###
    Get an array of the unique path to the field. A ListField's subfields are denoted by an integer representing the index of the subfield.
    A ContainerField's subfields are denoted by a string or integer representing the key of the subfield.
    Example:
    {parent: {child1: hello, child2: [the, quick, brown, fox]}}
    ["parent", "child2", 1] points to "quick"
    [] points to {parent: {child1: hello, child2: [the, quick, brown, fox]}}
    ###
    # if no parent, then the path is siply the empty list
    if @_parent
      return @_parent.getPath(this)
    else
      return []
  getField: (path) ->
    ### get a field given a path ###
    return if path.length > 0 then undefined else this
  emit: (eventName, inEvent) ->
    ###
    emit an event that bubbles up the field tree.
    
    * `eventName`: name of the event to emit
    * `inEvent`: optional hash of data to send with the event
    ###
    inEvent ?= {}
    inEvent.originator = this
    @_bubble(eventName, null, inEvent)

  _bubble: (eventName, inSender, inEvent) ->
    ### handle bubbling to parent ###
    for listener in @_getProtoListeners(eventName, true)
      if listener.apply(this, [inSender, inEvent]) == true then return
    if @_parent
      @_parent._bubble(eventName, this, inEvent)

  _getProtoListeners: (eventName, start) ->
    ### handle bubbling up the prototype chain ###
    sup = if start then @constructor.prototype else @constructor.__super__
    listener = @listeners[eventName] or @listeners["*"]
    listener = if listener instanceof Function then listener else this[listener]
    listener = if listener? then [listener] else []
    if sup?
      return sup._getProtoListeners(eventName).concat(listener)
    else
      return listener
      


class CharField extends Field
  ###
  a field that contains a string.  
  Attributes:

   * `maxLength`: The maximum length of the string (optional)
   * `minLength`: The minimum length of the string (optional)

  Default widget: Widget
  ###
  # The maximum length of the string (optional)
  maxLength: undefined
  ### The minimum length of the string (optional) ###
  minLength: undefined
  constructor: (opts) ->
    super(opts)
    if @maxLength?
      @validators.push(new validators.MaxLengthValidator(@maxLength))
    if @minLength?
      @validators.push(new validators.MinLengthValidator(@minLength))
  toJavascript: (value) ->
    value = if validators.isEmpty(value) then "" else value
    return value




class IntegerField extends Field
  ###
  a field that contains a whole number.  
  Attributes:  

   * `maxValue`: Maximum value of integer
   * `minValue`: Minimum value of integer

  Default widget: Widget
  ###
  # Maximum value of integer
  maxValue: undefined
  # Minimum value of integer
  minValue: undefined
  errorMessages: {
    invalid: utils._i('Enter a whole number.')
  },
  constructor: (opts) ->
    super(opts)
    if @maxValue?
      @validators.push(new validators.MaxValueValidator(@maxValue))
    if @minValue?
      @validators.push(new validators.MinValueValidator(@minValue))
  parseFn: parseInt
  regex: /^-?\d*$/
  toJavascript: (value) ->
    if typeof(value) == "string" and not value.match(@regex)
      throw ValidationError(@errorMessages.invalid, "invalid")
    value = if validators.isEmpty(value) then undefined else @parseFn(value, 10)
    if value? and isNaN(value)
      throw ValidationError(@errorMessages.invalid, "invalid")
    return value


class FloatField extends IntegerField
  ###
  A field that contains a floating point number.  
  Attributes:

    * `maxDecimals`: Maximum number of digits after the decimal point
    * `minDecimals`: Minimum number of digits after the decimal point
    * `maxDigits`: Maximum number of total digits before and after the decimal point
  
  Default widget: Widget
  ###
  # Maximum number of digits after the decimal point
  maxDecimals: undefined,
  # Minimum number of digits after the decimal point
  minDecimals: undefined,
  # Maximum number of total digits before and after the decimal point
  maxDigits: undefined
  # @protected
  errorMessages:
    invalid: utils._i('Enter a number.')
  constructor: (opts) ->
    super(opts)
    if @maxDecimals?
      @validators.push(new validators.MaxDecimalPlacesValidator(@maxDecimals))
    if @minDecimals?
      @validators.push(new validators.MinDecimalPlacesValidator(@minDecimals))
    if @maxDigits?
      @validators.push(new validators.MaxDigitsValidator(@maxDigits))
  parseFn: parseFloat
  regex: /^\d*\.?\d*$/

# a basic Regex Field for subclassing.
class RegexField extends Field
  ###
  A baseclass for subclassing.
  Attributes:

    * `regex`: the compiled regex to test against
    * `errorMessage`: the error message to display when the regex fails
  
  Default widget: Widget
  ###
  # the compiled regex to test against.
  regex: undefined,
  # the error message to display when the regex fails
  errorMessage: undefined
  # @protected
  constructor: (opts) ->
    super(opts)
    @validators.push(new validators.RegexValidator(@regex))
    if @errorMessage
      @errorMessages.invalid = @errorMessage



class EmailField extends RegexField
  ###
  A field that contains a valid email.  
  Attributes:

    * None
  
  Default widget: EmailWidget
  ###
  widget: "widgets.EmailWidget"
  validators: [new validators.EmailValidator()]

class BooleanField extends Field
  ###
  A field that contains a Boolean value. Must be true or false.
  if you want to be able to store null us `NullBooleanField`
  Attributes:

    * none
  
  Default widget: CheckboxWidget
  ###
  widget: "widgets.CheckboxWidget"
  # @protected
  toJavascript: (value) ->
    if typeof(value) == "string" and value.toLowerCase() in ["false", "0"]
      value = false
    else
      value = Boolean(value)
    if not value and @required
      throw ValidationError(@errorMessages.required, "required")
    return value

class NullBooleanField extends BooleanField
  ###
  A field that contains a Boolean value. The value can be 
  true, false, or null.  
  Attributes:

    * none
  
  Default widget: CheckboxWidget
  ###
  toJavascript: (value) ->
    if value in [true, "True", "1"]
      value =  true
    else if value in [false, "False", "0"]
      value = false
    else 
      value = null
    return value
  validate: (value) ->
    return value


class ChoiceField extends Field
  ###
  A field that contains value from a list of values.  
  Attributes:

    * `choices`: Array of 2-arrays specifying valid choices. if 2-arrays, first value is value, second is display. create optgroups by setting display If display value to a 2-array. MUST USE `setChoices`.
  
  Default widget: ChoiceWidget
  ###
  widget: "widgets.ChoiceWidget"
  # Array of 2-arrays specifying valid choices. if 2-arrays, first value is value, second is display. create optgroups by setting display If display value to a 2-array. MUST USE SETTER.
  choices: []
  errorMessages:
    invalidChoice: utils._i('Select a valid choice. %(value)s is not one of the available choices.')
  constructor: (opts) ->
    if opts.choices then @choices = opts.choices
    @setChoices(_.clone(@choices))
    super(opts)

  setChoices: (val) ->
    choices = {};
    iterChoices = (x) ->
      if (x[1] instanceof Array) then _.forEach(x[1], iterChoices)
      else choices[x[0]] = x[1];
    _.forEach(@choices, iterChoices)
    @choicesIndex = choices
  toJavascript: (value) ->
    value = if validators.isEmpty(value) then "" else value
    return value
  validate: (value) ->
    value = super(value)
    if value and not @validValue(value)
      throw ValidationError(@errorMessages.invalidChoice, "invalidChoice", value)
    return value
  validValue: (val) ->
    return val of @choicesIndex
  getDisplay: () ->
    return @choices[@getClean()]

fields =
  Field: Field
  CharField: CharField
  IntegerField: IntegerField
  FloatField: FloatField
  RegexField: RegexField
  EmailField: EmailField
  BooleanField: BooleanField
  NullBooleanField: NullBooleanField
  ChoiceField: ChoiceField
  # get a variable from the global variable, g, identified by a dot-delimited string
  getField: (path) ->
    path = path.split(".")
    out = this
    for part in path
      out = out[part]
    return out
  # generate a field from its schema
  genField: (schema, parent, value) ->
    schema = _.clone(schema)
    schema._parent = parent
    if value? then schema.value = value
    field = @getField(schema.field)
    if not field then throw Error("Unknown field: "+ schema.field)
    return new field(schema)


if window?
  window.fields = fields
else if exports?
  require("./ContainerFields")(fields)
  module.exports = fields