// Generated by CoffeeScript 1.9.1
(function() {
  var BaseContainerField, ContainerField, HashField, ListField, _, fields, utils,
    extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
    hasProp = {}.hasOwnProperty,
    slice = [].slice;

  if (typeof exports !== "undefined" && exports !== null) {
    utils = require("./utils");
    _ = require("underscore");
    fields = require("./Fields");
  } else if (typeof window !== "undefined" && window !== null) {
    utils = window.validoc.utils;
    fields = window.validoc.fields;
    _ = window._;
  }


  /*
  ValiDoc allows you to create arbitrarily nested forms, to validate arbitrary data structures.
  You do this by using ContainerFields. create a nested form by creating a containerField
  then adding childFields to the schema. See example in README.md.
   */

  BaseContainerField = (function(superClass) {
    extend(BaseContainerField, superClass);


    /*
      _fields.BaseContainerField_ is the baseclass for all container-type fields.
      ValiDoc allows you to create, validate and display arbitrarily complex
      nested data structures. container-type fields contain other fields. There
      are currently two types. A `ContainerField`, analogous to a hash of childFields,
      and a `ListField`, analogous to a list of childFields. container-type fields
      act in most ways like a regular field. You can set them, and all their childFields
      with `setValue`, you can get their, and all their childFields', data with
      `getClean` or `toJSON`.
    
      When a childField is invalid, the containing field will also be invalid.
    
      You specify a container's childFields in the `schema` attribute. Each container type
      accepts a different format for the `schema`.
    
      ValiDoc schemas are fully recursive - that is, containers can contain containers,
      allowing you to model and validate highly nested datastructures like you might find
      in a document database.
     */

    BaseContainerField.prototype.schema = void 0;

    BaseContainerField.prototype._fields = void 0;

    BaseContainerField.prototype.errorMessages = {
      required: utils._i('There must be at least one %s.'),
      invalidChild: utils._i('Please fix the errors indicated below.')
    };

    function BaseContainerField(schema, opts, parent) {
      BaseContainerField.__super__.constructor.call(this, schema, opts, parent);
      this._createChildFields();
    }

    BaseContainerField.prototype.validate = function(value) {
      var valid;
      valid = true;
      _.forEach(this.getFields(), (function(_this) {
        return function(field) {
          if (!field.isValid()) {
            return valid = false;
          }
        };
      })(this));
      if (!valid) {
        throw utils.ValidationError(this.errorMessages.invalidChild, 'invalidChild');
      }
      return value;
    };

    BaseContainerField.prototype._querychildFields = function() {
      var args, fn;
      fn = arguments[0], args = 2 <= arguments.length ? slice.call(arguments, 1) : [];

      /* get data from each childField `fn` and put it into the appropriate data structure */
      return _.map(this.getFields(), function(x) {
        return x[fn].apply(x, args);
      });
    };

    BaseContainerField.prototype.getFields = function() {
      return this._fields;
    };

    BaseContainerField.prototype.getField = function(path) {

      /*
      return an arbitrarily deep childField given a path. Path can be an array
      of indexes/names, or it can be a dot-delimited string
       */
      var childField;
      if (!path || path.length === 0) {
        return this;
      }
      if (typeof path === "string") {
        path = path.split(".");
      }
      childField = this._getField(path.shift());
      if (childField == null) {
        return void 0;
      }
      return childField.getField(path);
    };

    BaseContainerField.prototype.getValue = function(path) {
      if (path != null ? path.length : void 0) {
        return this._applyTochildField("getValue", path);
      } else {
        return this._value;
      }
    };

    BaseContainerField.prototype.getClean = function(path) {
      if (path != null ? path.length : void 0) {
        return this._applyTochildField("getClean", path);
      } else {
        this._throwErrorIfInvalid();
        return this._clean;
      }
    };

    BaseContainerField.prototype.toJSON = function(path) {
      if (path != null ? path.length : void 0) {
        return this._applyTochildField("toJSON", path);
      } else {
        this._throwErrorIfInvalid();
        return this._querychildFields("toJSON");
      }
    };

    BaseContainerField.prototype.getErrors = function(path) {
      if (path != null ? path.length : void 0) {
        return this._applyTochildField("getErrors", path);
      } else {

      }
      this.isValid();
      if (this._errors.length) {
        return this._querychildFields("getErrors");
      } else {
        return [];
      }
    };

    BaseContainerField.prototype._createChildFields = function() {
      throw new Error('not implemented');
    };

    BaseContainerField.prototype._addField = function(schema, value) {
      var field;
      schema = _.clone(schema);
      schema._parent = this;
      if (value != null) {
        schema.value = value;
      }
      field = fields.genField(schema, this, value);
      return field;
    };

    BaseContainerField.prototype._applyTochildField = function() {
      var args, childField, fn, path;
      fn = arguments[0], path = arguments[1], args = 3 <= arguments.length ? slice.call(arguments, 2) : [];
      childField = this.getField(path);
      if (!childField) {
        throw Error("Field does not exist: " + String(path));
      }
      return childField[fn].apply(childField, args);
    };

    return BaseContainerField;

  })(fields.Field);

  ContainerField = (function(superClass) {
    extend(ContainerField, superClass);

    function ContainerField() {
      return ContainerField.__super__.constructor.apply(this, arguments);
    }


    /*
      A ContainerField contains a number of heterogeneous
      childFields. When data is extracted from it using `toJSON`, or `getClean`, the
      returned data is in a hash object where the key is the name of the childField
      and the value is the value of the childField.
    
      the schema for a ContainerField is an Array of kind definition objects such as
      `[{kind: "CharField", maxLength: 50 }, {kind:IntegerField }`.
      The ContainerField will contain the specified array of heterogenious fields.
     */

    ContainerField.prototype.widget = "widgets.ContainerWidget";

    ContainerField.prototype["default"] = {};

    ContainerField.prototype.errorMessages = {
      invalid: utils._i('%s must be a hash')
    };

    ContainerField.prototype._createChildFields = function() {
      var initialValue, value;
      value = this.getValue();
      value = _.isObject(value) && !_.isArray(value) ? value : {};
      initialValue = this.getInitialValue();
      initialValue = _.isObject(initialValue) && !_.isArray(initialValue) ? initialValue : {};
      return this._fields = _.map(this.schema, (function(_this) {
        return function(childSchema) {
          var opts;
          opts = _.clone(_this.opts);
          opts.value = value[childSchema.name];
          opts.initialValue = initialValue[childSchema.name];
          return fields.genField(childSchema, opts, _this);
        };
      })(this));
    };

    ContainerField.prototype.validate = function(value) {
      if (!utils.isHash(value)) {
        throw utils.ValidationError(this.errorMessages.invalid, "invalid", JSON.stringify(value));
      } else {
        return ContainerField.__super__.validate.call(this, value);
      }
    };

    ContainerField.prototype._getField = function(name) {
      var field, j, len, ref;
      ref = this.getFields();
      for (j = 0, len = ref.length; j < len; j++) {
        field = ref[j];
        if (field.name === name) {
          return field;
        }
      }
    };

    ContainerField.prototype._querychildFields = function() {
      var args, fn, out;
      fn = arguments[0], args = 2 <= arguments.length ? slice.call(arguments, 1) : [];
      out = {};
      _.forEach(this.getFields(), function(x) {
        return out[x.name] = x[fn].apply(x, args);
      });
      return out;
    };

    ContainerField.prototype.getPath = function(childField) {
      var end;
      end = [];
      if (childField) {
        end.push(childField.name);
      }
      if (this._parent) {
        return this._parent.getPath(this).concat(end);
      } else {
        return end;
      }
    };

    return ContainerField;

  })(BaseContainerField);

  HashField = (function(superClass) {
    extend(HashField, superClass);

    function HashField() {
      return HashField.__super__.constructor.apply(this, arguments);
    }


    /*
        A HashField contains an arbitrary number of identical childFields in a hash
        (javascript object). When data is extracted from it using `toJSON`, or 
        `getClean`, the returned data is in an object where each value is the value 
        of the childField at the corresponding key.
    
        A HashField's `schema` consists of a single field definition, such as
        `{ kind: "email" }`.
    
        This doesn't really seem to have a use case for a widget, just for arbitrary
        json validation. so no widget is provided
     */

    HashField.prototype.widget = null;

    HashField.prototype["default"] = {};

    HashField.prototype.errorMessages = {
      invalid: utils._i('%s must be a hash')
    };

    HashField.prototype._createChildFields = function() {
      var initialValue, keys, value;
      value = this.getValue();
      value = _.isObject(value) && !_.isArray(value) ? value : {};
      initialValue = this.getInitialValue();
      initialValue = _.isObject(initialValue) && !_.isArray(initialValue) ? initialValue : {};
      keys = _.union(_.keys(value), _.keys(initialValue));
      return this._fields = _.map(keys, (function(_this) {
        return function(key) {
          var opts, schema;
          schema = _.clone(_this.schema);
          schema.name = key;
          opts = _.clone(_this.opts);
          opts.value = value[key];
          opts.initialValue = initialValue[key];
          return fields.genField(schema, opts, _this);
        };
      })(this));
    };

    HashField.prototype.validate = function(value) {
      var itemName;
      if (_.isEmpty(value) && this.required) {
        itemName = this.schema.name || (_.isString(this.schema.field) && this.schema.field.slice(0, -5)) || "item";
        throw utils.ValidationError(this.errorMessages.required, 'required', this.schema.name || (_.isString(this.schema.field) && this.schema.field.slice(0, -5)) || "item");
      } else {
        return HashField.__super__.validate.call(this, value);
      }
    };

    return HashField;

  })(ContainerField);

  ListField = (function(superClass) {
    extend(ListField, superClass);

    function ListField() {
      return ListField.__super__.constructor.apply(this, arguments);
    }


    /*
        A ListField contains an arbitrary number of identical childFields in a
        list. When data is extracted from it using `toJSON`, or `getClean`, the
        returned data is in a list where each value is the value of the childField at
        the corresponding index.
    
        A ListField's `schema` consists of a single field definition, such as
        `{ kind: "email" }`.
     */

    ListField.prototype.widget = "widgets.ListWidget";

    ListField.prototype["default"] = [];

    ListField.prototype.errorMessages = {
      invalid: utils._i('%s must be an array')
    };

    ListField.prototype._createChildFields = function() {
      var initialValue, value;
      value = this.getValue();
      value = _.isArray(value) ? value : [];
      initialValue = this.getInitialValue();
      initialValue = _.isArray(initialValue) ? initialValue : {};
      return this._fields = _.map(value, (function(_this) {
        return function(childValue, i) {
          var childInitialValue, opts;
          childInitialValue = initialValue[i];
          opts = _.clone(_this.opts);
          opts.value = childValue;
          opts.initialValue = childInitialValue;
          return fields.genField(_this.schema, opts, _this);
        };
      })(this));
    };

    ListField.prototype.validate = function(value) {
      var itemName;
      if (_.isEmpty(value) && this.required) {
        itemName = this.schema.name || (_.isString(this.schema.field) && this.schema.field.slice(0, -5)) || "item";
        throw utils.ValidationError(this.errorMessages.required, 'required', this.schema.name || (_.isString(this.schema.field) && this.schema.field.slice(0, -5)) || "item");
      } else if (!_.isArray(value)) {
        throw utils.ValidationError(this.errorMessages.invalid, "invalid", JSON.stringify(value));
      } else {
        return ListField.__super__.validate.call(this, value);
      }
    };

    ListField.prototype._getField = function(index) {

      /* get an immediate childField by index */
      return this.getFields()[index];
    };

    ListField.prototype.getPath = function(childField) {
      var end;
      end = [];
      if (childField) {
        end.push(this.getFields().indexOf(childField));
      }
      if (this._parent) {
        return this._parent.getPath(this).concat(end);
      } else {
        return end;
      }
    };

    return ListField;

  })(BaseContainerField);

  fields.BaseContainerField = BaseContainerField;

  fields.ContainerField = ContainerField;

  fields.HashField = HashField;

  fields.ListField = ListField;

  if (typeof exports !== "undefined" && exports !== null) {
    module.exports = fields;
  }

}).call(this);