/*

Простая JS-библиотека для организации Drag&Drop (не HTML5)
http://yourcmc.ru/wiki/JSLib#Drag.26Drop
(c) Виталий Филиппов, 2010-2011
Основано на уроке Ильи Кантора http://javascript.ru/ui/draganddrop

Использование:
  dragObject = new DragObject(element); // то, что тащим
  dropTarget = new DropTarget(element); // то, куда тащим

Обработчики DropTarget:
* boolean dropTarget.canAccept(DragObject)
  Вернуть true, если эта цель может принять этот DragObject
* dropTarget.onAccept(DragObject, pos = { x: int, y: int })
  Объект перетаскивают на эту цель и отпускают
  x, y - относительные цели координаты, в которых объект отпущен
* dropTarget.onEnter()
  Объект приносят на этой цель
* dropTarget.onLeave()
  Объект уносят с этой цели
* dropTarget.onMove(pos = { x: int, y: int })
  Объект таскают по цели
  x, y - относительные цели координаты, в которых объект находится

Обработчики DragObject:
* dragObject.onDragStart(offset = { x: int, y: int })
  Объект начинают перетаскивать
  x, y - относительные координаты, за которые пользователь взял объект мышкой
* dragObject.onDragMove(x, y)
  Объект перетаскивают
  x, y - абсолютные координаты нахождения объекта
* dragObject.onDragSuccess(DropTarget, pos = { x: int, y: int })
  Объект принят целью
  x, y - относительные цели координаты, в которых объект отпущен
* dragObject.onDragFail()
  Объект не принят ни одной целью

Соответственно, все эти обработчики можно переопределять. Так и работаем.
Можно даже унаследоваться от класса и написать обработчики прототипами:
  function MyDropTarget(e) { DropTarget.call(this, e); }
  MyDropTarget.prototype = new DropTarget();
  MyDropTarget.prototype.onAccept = function(obj, pos) {...};

Ещё можно использовать кое-что в DragMaster'е:
* Event DragMaster.fixEvent(Event e)
  Фиксит некоторые не-кроссбраузерности в событии:
  * e       = e || window.event
  * pX, pY  = правильным смещениям клика мышкой от начала документа
  * which   = добавляется для IE
  * _target = правильная кроссбраузерная цель события
* DragMaster.noDragElements = { 'nodeName' => true|false }
  Отключает перетаскивание при клике на элементе nodeName, даже
  если он содержится внутри перетаскиваемого объекта.
  По умолчанию это input, textarea, button.

*/

var DragMaster = (function()
{
    var dragObject;
    var mouseDownAt;
    var currentDropTarget;

    var self = {};

    self.noDragElements = { 'input': 1, 'textarea': 1, 'button': 1 };

    self.usePageX = (function()
    {
        var m = navigator.userAgent.match(/Opera.([\d\.]+)/);
        var mv;
        if (m && (mv = navigator.userAgent.match(/Version\/([\d\.]+)/)))
            m = mv;
        var sf = navigator.userAgent.match(/Safari\//) &&
            !navigator.userAgent.match(/Chrome/);
        if (sf || m && parseFloat(m[1]) < 10.5)
            return true;
        return false;
    })();

    self.fixEvent = function(e)
    {
        // получить объект событие для IE
        e = e || window.event;

        // добавить pageX/pageY для IE
        if (e.pageX == null && e.clientX != null)
        {
            var html = document.documentElement;
            var body = document.body;
            e.pageX = e.clientX + (html && html.scrollLeft || body && body.scrollLeft || 0) - (html.clientLeft || 0);
            e.pageY = e.clientY + (html && html.scrollTop || body && body.scrollTop || 0) - (html.clientTop || 0);
        }

        // правильный pageX/pageY
        if (self.usePageX && e.pageX != null)
        {
            e.pX = e.pageX;
            e.pY = e.pageY;
        }
        else if (e.pageY != null)
        {
            e.pX = e.clientX;
            e.pY = e.clientY;
        }

        // добавить which для IE
        if (!e.which && e.button)
            e.which = e.button & 1 ? 1 : ( e.button & 2 ? 3 : ( e.button & 4 ? 2 : 0 ) );

        // добавить кроссбраузерную цель события
        var t = e.target;
        if (!t)
          t = e.srcElement;
        if (t && t.nodeType == 3)
          t = t.parentNode; // Safari bug
        e._target = t;

        return e;
    };

    function getOffset(elem)
    {
        if (elem.getBoundingClientRect)
            return getOffsetRect(elem);
        else
            return getOffsetSum(elem);
    };

    function getOffsetRect(elem)
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

    function getOffsetSum(elem)
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

    function mouseDown(e)
    {
        e = self.fixEvent(e);
        if (self.noDragElements[e._target.nodeName.toLowerCase()])
            return true;
        if (e.which != 1)
            return false;
        mouseDownAt = { x: e.pageX, y: e.pageY, element: this };
        addDocumentEventHandlers();
        return false;
    };

    function mouseMove(e)
    {
        e = self.fixEvent(e);

        // (1)
        if (mouseDownAt)
        {
            if (Math.abs(mouseDownAt.x-e.pageX) < 5 &&
                Math.abs(mouseDownAt.y-e.pageY) < 5)
                return false;
            // Начать перенос
            var elem = mouseDownAt.element;
            // текущий объект для переноса
            dragObject = elem.dragObject;

            // запомнить, с каких относительных координат начался перенос
            var mouseOffset = getMouseOffset(elem, mouseDownAt.x, mouseDownAt.y);
            mouseDownAt = null; // запомненное значение больше не нужно, сдвиг уже вычислен

            dragObject.dragStart(mouseOffset); // начали
        }

        // (2)
        dragObject.dragMove(e.pageX, e.pageY);
        dragObject.element._moved = true;

        // (3)
        var newTarget = getCurrentTarget(e);

        // (4)
        if (currentDropTarget != newTarget)
        {
            if (currentDropTarget && currentDropTarget.onLeave)
                currentDropTarget.onLeave();
            if (newTarget && newTarget.onEnter)
                newTarget.onEnter();
            currentDropTarget = newTarget;
        }
        if (currentDropTarget && currentDropTarget.onMove)
            currentDropTarget.onMove(getMouseOffset(currentDropTarget.element, e.pX, e.pY));

        // (5)
        return false;
    };

    function mouseUp(e)
    {
        e = self.fixEvent(e);

        if (!dragObject) // (1)
            mouseDownAt = null;
        else
        {
            // (2)
            if (currentDropTarget)
            {
                var pos = getMouseOffset(currentDropTarget.element, e.pX, e.pY);
                currentDropTarget.accept(dragObject, pos);
                dragObject.dragSuccess(currentDropTarget, pos);
            }
            else
                dragObject.dragFail();
            dragObject = null;
        }

        // (3)
        removeDocumentEventHandlers();
    };

    function getMouseOffset(target, x, y)
    {
        var docPos = getOffset(target);
        return { x: x-docPos.left, y: y-docPos.top };
    };

    function getCurrentTarget(e)
    {
        // спрятать объект, получить элемент под ним - и тут же показать опять
        var x = e.pX, y = e.pY;
        // чтобы не было заметно мигание - максимально снизим время от hide до show
        dragObject.hide();
        var elem = document.elementFromPoint(x, y);
        dragObject.show();

        // найти самую вложенную dropTarget
        while (elem)
        {
            // которая может принять dragObject
            if (elem.dropTarget && (!elem.dropTarget.canAccept || elem.dropTarget.canAccept(dragObject)))
                return elem.dropTarget;
            elem = elem.parentNode;
        }

        // dropTarget не нашли
        return null;
    };

    function addDocumentEventHandlers()
    {
        document.onmousemove = mouseMove;
        document.onmouseup = mouseUp;
        document.ondragstart = document.body.onselectstart = function() { return false };
    };

    function removeDocumentEventHandlers()
    {
        document.onmousemove =
        document.onmouseup =
        document.ondragstart =
        document.body.onselectstart = null;
    };

    self.makeDraggable = function(element)
    {
        element.onmousedown = mouseDown;
        element.onclick = function()
        {
            var r = element._moved && true;
            element._moved = false;
            return !r;
        };
    }

    return self;
}());

/* DragObject */

function DragObject(element)
{
    if (!element)
        return;
    element.dragObject = this;
    DragMaster.makeDraggable(element);
    this.element = element;
}

DragObject.prototype.dragStart = function(offset)
{
    var s = this.element.style;
    this.rememberPosition = {
        top: s.top,
        left: s.left,
        position: s.position,
        opacity: s.opacity
    };
    s.position = 'absolute';
    this.mouseOffset = offset;
    if (this.onDragStart)
        this.onDragStart(offset);
};

DragObject.prototype.hide = function()
{
    this.element.style.display = 'none';
};

DragObject.prototype.show = function()
{
    this.element.style.display = '';
};

DragObject.prototype.dragMove = function(x, y)
{
    this.element.style.top = y - this.mouseOffset.y + 'px';
    this.element.style.left = x - this.mouseOffset.x + 'px';
    if (this.onDragMove)
        this.onDragMove(x, y);
};

DragObject.prototype.dragSuccess = function(dropTarget, pos)
{
    this.restorePosition();
    if (this.onDragSuccess)
        this.onDragSuccess(dropTarget, pos);
};

DragObject.prototype.restorePosition = function()
{
    var s = this.element.style;
    for (var i in this.rememberPosition)
        s[i] = this.rememberPosition[i];
};

DragObject.prototype.dragFail = function()
{
    this.restorePosition()
    if (this.onDragFail)
        this.onDragFail();
};

/* DropTarget */

function DropTarget(element)
{
    if (!element)
        return;
    element.dropTarget = this;
    this.element = element;
};

DropTarget.prototype.accept = function(dragObject, pos)
{
    if (this.onAccept)
        this.onAccept(dragObject, pos);
    if (this.onLeave)
        this.onLeave();
};
