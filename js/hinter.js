/* Simple autocomplete for text inputs, with the support for multiple selection.
   Homepage: http://yourcmc.ru/wiki/SimpleAutocomplete
   (c) Vitaliy Filippov 2011
   Usage:
     Include hinter.css, hinter.js on your page. Then write:
     var hint = new SimpleAutocomplete(input, dataLoader, multipleDelimiter, onChangeListener, maxHeight, emptyText, allowHTML);
   Parameters:
     input
       The input, either id or DOM element reference (the input must have an id anyway).
     dataLoader(hint, value)
       Callback which should load autocomplete options and then call
       hint.replaceItems([ [ name, value ], [ name, value ], ... ])
       'hint' parameter will be this autocompleter object, and the guess
       should be done based on 'value' parameter (string).
   Optional parameters:
     multipleDelimiter
       Pass a delimiter string (for example ',' or ';') to enable multiple selection.
       Item values cannot have leading or trailing whitespace. Input value will consist
       of selected item values separated by this delimiter plus single space.
       dataLoader should handle it's 'value' parameter accordingly in this case,
       because it will be just the raw value of the input, probably with incomplete
       item or items, typed by the user.
     onChangeListener(hint, index)
       Callback which is called when input value is changed using this dropdown.
       index is the number of element which selection is changed, starting with 0.
       It must be used instead of normal 'onchange' event.
     maxHeight
       Maximum hint dropdown height in pixels
     emptyText
       Text to show when dataLoader returns no options.
       If emptyText === false, the hint will be hidden instead of showing text.
     allowHTML
       If true, HTML code will be allowed in option names.
*/

var SimpleAutocomplete = function(input, dataLoader, multipleDelimiter, onChangeListener, maxHeight, emptyText, allowHTML)
{
    if (typeof(input) == 'string')
        input = document.getElementById(input);
    if (emptyText === undefined)
        emptyText = 'No items found';

    // Parameters
    var self = this;
    self.input = input;
    self.multipleDelimiter = multipleDelimiter;
    self.dataLoader = dataLoader;
    self.onChangeListener = onChangeListener;
    self.maxHeight = maxHeight;
    self.emptyText = emptyText;
    self.allowHTML = allowHTML;

    // Variables
    self.items = [];
    self.skipHideCounter = 0;
    self.selectedIndex = -1;
    self.id = input.id;
    self.disabled = false;

    // Initialiser
    var init = function()
    {
        var e = self.input;
        var p = getOffset(e);

        // Create hint layer
        var t = self.hintLayer = document.createElement('div');
        t.className = 'hintLayer';
        t.style.display = 'none';
        t.style.position = 'absolute';
        t.style.top = (p.top+e.offsetHeight) + 'px';
        t.style.zIndex = 1000;
        t.style.left = p.left + 'px';
        if (self.maxHeight)
        {
            t.style.overflowY = 'scroll';
            try { t.style.overflow = '-moz-scrollbars-vertical'; } catch(exc) {}
            t.style.maxHeight = self.maxHeight+'px';
            if (!t.style.maxHeight)
                self.scriptMaxHeight = true;
        }
        document.body.appendChild(t);

        // Remember instance
        e.SimpleAutocomplete_input = self;
        t.SimpleAutocomplete_layer = self;
        SimpleAutocomplete.SimpleAutocompletes.push(self);

        // Set event listeners
        var msie = navigator.userAgent.match('MSIE') && !navigator.userAgent.match('Opera');
        if (msie)
            addListener(e, 'keydown', self.onKeyPress);
        else
        {
            addListener(e, 'keydown', self.onKeyDown);
            addListener(e, 'keypress', self.onKeyPress);
        }
        addListener(e, 'keyup', self.onKeyUp);
        addListener(e, 'change', self.onChange);
        addListener(e, 'focus', self.onInputFocus);
        addListener(e, 'blur', self.onInputBlur);
        self.onChange();
    };

    // obj = [ [ name, value, disabled ], [ name, value ], ... ]
    self.replaceItems = function(items)
    {
        self.hintLayer.innerHTML = '';
        self.hintLayer.scrollTop = 0;
        self.items = [];
        if (!items || items.length == 0)
        {
            if (self.emptyText)
            {
                var d = document.createElement('div');
                d.className = 'hintEmptyText';
                d.innerHTML = self.emptyText;
                self.hintLayer.appendChild(d);
            }
            else
                self.disable();
            return;
        }
        self.enable();
        var h = {};
        if (self.multipleDelimiter)
        {
            var old = self.input.value.split(self.multipleDelimiter);
            for (var i = 0; i < old.length; i++)
                h[old[i].trim()] = true;
        }
        for (var i in items)
            self.hintLayer.appendChild(self.makeItem(items[i][0], items[i][1], h[items[i][1]]));
        if (self.maxHeight)
        {
            self.hintLayer.style.height =
                (self.hintLayer.scrollHeight > self.maxHeight
                ? self.maxHeight : self.hintLayer.scrollHeight) + 'px';
        }
    };

    // Create a drop-down list item, include checkbox if self.multipleDelimiter is true
    self.makeItem = function(name, value, checked)
    {
        var d = document.createElement('div');
        d.id = self.id+'_item_'+self.items.length;
        d.className = 'hintItem';
        d.title = value;
        if (self.allowHTML)
            d.innerHTML = name;
        if (self.multipleDelimiter)
        {
            var c = document.createElement('input');
            c.type = 'checkbox';
            c.id = self.id+'_check_'+self.items.length;
            c.checked = checked && true;
            c.value = value;
            if (d.childNodes.length)
                d.insertBefore(c, d.firstChild);
            else
                d.appendChild(c);
            addListener(c, 'click', self.preventCheck);
        }
        if (!self.allowHTML)
            d.appendChild(document.createTextNode(name));
        addListener(d, 'mouseover', self.onItemMouseOver);
        addListener(d, 'mousedown', self.onItemClick);
        self.items.push([name, value, checked]);
        return d;
    };

    // Prevent default action on checkbox
    self.preventCheck = function(ev)
    {
        ev = ev||window.event;
        return stopEvent(ev, false, true);
    };

    // Handle item mouse over
    self.onItemMouseOver = function()
    {
        return self.highlightItem(this);
    };

    // Handle item clicks
    self.onItemClick = function(ev)
    {
        self.selectItem(parseInt(this.id.substr(self.id.length+6)));
        return true;
    };

    // Move highlight forward or back by 'by' items (integer)
    self.moveHighlight = function(by)
    {
        var n = self.selectedIndex+by;
        if (n < 0)
            n = 0;
        var elem = document.getElementById(self.id+'_item_'+n);
        if (!elem)
            return true;
        return self.highlightItem(elem);
    };

    // Make item 'elem' active (highlighted)
    self.highlightItem = function(elem)
    {
        if (self.selectedIndex >= 0)
        {
            var c = self.getItem();
            if (c)
                c.className = 'hintItem';
        }
        self.selectedIndex = parseInt(elem.id.substr(self.id.length+6));
        elem.className = 'hintActiveItem';
        return false;
    };

    // Get index'th item, or current when index is null
    self.getItem = function(index)
    {
        if (index == null)
            index = self.selectedIndex;
        if (index < 0)
            return null;
        return document.getElementById(self.id+'_item_'+self.selectedIndex);
    };

    // Select index'th item - change the input value and hide the hint if not a multi-select
    self.selectItem = function(index)
    {
        if (!self.multipleDelimiter)
        {
            self.input.value = self.items[index][1];
            self.hide();
        }
        else
        {
            document.getElementById(self.id+'_check_'+index).checked = self.items[index][2] = !self.items[index][2];
            var old = self.input.value.split(self.multipleDelimiter);
            for (var i = 0; i < old.length; i++)
                old[i] = old[i].trim();
            if (!self.items[index][2])
            {
                for (var i = old.length-1; i >= 0; i--)
                    if (old[i] == self.items[index][1])
                        old.splice(i, 1);
                self.input.value = old.join(self.multipleDelimiter+' ');
            }
            else
            {
                var h = {};
                for (var i = 0; i < self.items.length; i++)
                    if (self.items[i][2])
                        h[self.items[i][1]] = true;
                var nl = [];
                for (var i = 0; i < old.length; i++)
                {
                    if (h[old[i]])
                    {
                        delete h[old[i]];
                        nl.push(old[i]);
                    }
                }
                for (var i = 0; i < self.items.length; i++)
                    if (self.items[i][2] && h[self.items[i][1]])
                        nl.push(self.items[i][1]);
                self.input.value = nl.join(self.multipleDelimiter+' ');
            }
        }
        if (self.onChangeListener)
            self.onChangeListener(self, index);
    };

    // Handle user input, load new items
    self.onChange = function()
    {
        var v = self.input.value.trim();
        if (v != self.curValue)
        {
            self.curValue = v;
            self.dataLoader(self, v);
        }
        return true;
    };

    // Handle Enter key presses, cancel handling of arrow keys
    self.onKeyUp = function(ev)
    {
        ev = ev||window.event;
        if (ev.keyCode != 10 && ev.keyCode != 13)
            self.show();
        if (ev.keyCode == 38 || ev.keyCode == 40 || ev.keyCode == 10 || ev.keyCode == 13)
            return stopEvent(ev, true, true);
        self.onChange();
        return true;
    };

    // Cancel handling of Enter key
    self.onKeyDown = function(ev)
    {
        ev = ev||window.event;
        if (ev.keyCode == 10 || ev.keyCode == 13)
            return stopEvent(ev, true, true);
        return true;
    };

    // Handle arrow keys and Enter
    self.onKeyPress = function(ev)
    {
        ev = ev||window.event;
        if (ev.keyCode == 38) // up
            self.moveHighlight(-1);
        else if (ev.keyCode == 40) // down
            self.moveHighlight(1);
        else if (ev.keyCode == 10 || ev.keyCode == 13) // enter
        {
            if (self.selectedIndex >= 0)
                self.selectItem(self.selectedIndex);
            return stopEvent(ev, true, true);
        }
        else
            return true;
        // scrolling
        if (self.selectedIndex >= 0)
        {
            var c = self.getItem();
            var t = self.hintLayer;
            var ct = getOffset(c).top + t.scrollTop - t.style.top.substr(0, t.style.top.length-2);
            var ch = c.scrollHeight;
            if (ct+ch-t.offsetHeight > t.scrollTop)
                t.scrollTop = ct+ch-t.offsetHeight;
            else if (ct < t.scrollTop)
                t.scrollTop = ct;
        }
        return stopEvent(ev, true, true);
    };

    // Called when input receives focus
    self.onInputFocus = function()
    {
        self.show();
        self.hasFocus = true;
        return true;
    };

    // Called when input loses focus
    self.onInputBlur = function()
    {
        self.hide();
        self.hasFocus = false;
        return true;
    };

    // Hide hinter
    self.hide = function()
    {
        if (!self.skipHideCounter)
            self.hintLayer.style.display = 'none';
        else
            self.skipHideCounter = 0;
    };

    // Show hinter
    self.show = function()
    {
        var p = getOffset(self.input);
        self.hintLayer.style.top = (p.top+self.input.offsetHeight) + 'px';
        self.hintLayer.style.left = p.left + 'px';
        if (!self.disabled)
            self.hintLayer.style.display = '';
    };

    // Disable hinter, for the case when there is no items and no empty text
    self.disable = function()
    {
        self.disabled = true;
        self.hide();
    };

    // Enable hinter
    self.enable = function()
    {
        var show = self.disabled;
        self.disabled = false;
        if (show)
            self.show();
    }

    // *** Call initialise ***
    init();
};

// Global variable
SimpleAutocomplete.SimpleAutocompletes = [];

// Global mousedown handler, hides dropdowns when clicked outside
SimpleAutocomplete.GlobalMouseDown = function(ev)
{
    var target = ev.target || ev.srcElement;
    var esh;
    while (target)
    {
        esh = target.SimpleAutocomplete_input;
        if (esh)
            break;
        else if (target.SimpleAutocomplete_layer)
        {
            if (target.SimpleAutocomplete_layer.hasFocus)
                target.SimpleAutocomplete_layer.skipHideCounter++;
            return true;
        }
        target = target.parentNode;
    }
    for (var i in SimpleAutocomplete.SimpleAutocompletes)
        if (SimpleAutocomplete.SimpleAutocompletes[i] != esh)
            SimpleAutocomplete.SimpleAutocompletes[i].hide();
    return true;
};

//// UTILITY FUNCTIONS ////
// You can delete this section if you already have them somewhere in your scripts //

// Cancel event bubbling and/or default action
var stopEvent = function(ev, cancelBubble, preventDefault)
{
    if (cancelBubble)
    {
        if (ev.stopPropagation)
            ev.stopPropagation();
        else
            ev.cancelBubble = true;
    }
    if (preventDefault && ev.preventDefault)
        ev.preventDefault();
    ev.returnValue = !preventDefault;
    return !preventDefault;
};

// Get element position, relative to the top-left corner of page
var getOffset = function(elem)
{
    if (elem.getBoundingClientRect)
        return getOffsetRect(elem);
    else
        return getOffsetSum(elem);
};

// Get element position using getBoundingClientRect()
var getOffsetRect = function(elem)
{
    var box = elem.getBoundingClientRect();

    var body = document.body;
    var docElem = document.documentElement;

    var scrollTop = window.pageYOffset || docElem.scrollTop || body.scrollTop;
    var scrollLeft = window.pageXOffset || docElem.scrollLeft || body.scrollLeft;
    var clientTop = docElem.clientTop || body.clientTop || 0;
    var clientLeft = docElem.clientLeft || body.clientLeft || 0;
    var top = box.top + scrollTop - clientTop;
    var left = box.left + scrollLeft - clientLeft;

    return { top: Math.round(top), left: Math.round(left) };
};

// Get element position using sum of offsetTop/offsetLeft
var getOffsetSum = function(elem)
{
    var top = 0, left = 0;
    while(elem)
    {
        top = top + parseInt(elem.offsetTop);
        left = left + parseInt(elem.offsetLeft);
        elem = elem.offsetParent;
    }
    return { top: top, left: left };
};

//// END UTILITY FUNCTIONS ////

// Set global mousedown listener
addListener(window, 'load', function() { addListener(document, 'mousedown', SimpleAutocomplete.GlobalMouseDown) });
