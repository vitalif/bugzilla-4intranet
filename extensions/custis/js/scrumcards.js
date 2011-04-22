/**
Печать SCRUM-карточек из Bugzilla
(c) Виталий Филиппов 2010-2011

Весь смысл сего скрипта - манипуляции с расположением и набором карточек.
Даёт возможность удалять, добавлять, перемещать карточки.
Перемещение - методами drag&drop'а и вырезания/вставки.
**/
var pressedButton;
var pasteMode = false;
var ctrl = false;
var highlitCard;
var selectedcards = {};
var cuttedcards = [];
var cuttedids = [];
// Добавить карточки для багов с ID'шниками из поля addbugs
function addNewCards()
{
  for (var i = idlist.length-1; i >= 0; i--)
  {
    if (idlist[i] === '')
      idlist.pop();
    else
      break;
  }
  var val = document.getElementById('addbugs').value;
  var re = /(\d+)/g;
  var m;
  while (m = re.exec(val))
    idlist.push(m[1]);
  document.getElementById('idlist_value').value = idlist.join(',');
  document.getElementById('scrumform').submit();
}
// Добавить пустую страницу
function addEmptyPage()
{
  for (var i = 0; i < nr*nc; i++)
    idlist.push('');
  document.getElementById('idlist_value').value = idlist.join(',');
  document.getElementById('scrumform').submit();
}
// Обработчик нажатия Enter на поле addbugs
function addNewIfEnter(ev)
{
  if (ev.keyCode == 10 || ev.keyCode == 13)
  {
    addNewCards();
    return true;
  }
  return false;
}
// Удалить все карточки
function deleteAllCards()
{
  idlist = [];
  document.getElementById('idlist_value').value = idlist.join(',');
  document.getElementById('pages').innerHTML = '';
  document.getElementById('scrumform').submit();
}
// Сбросить состояние кнопок, выделение карточек, режим вставки
function resetAll()
{
  if (pressedButton)
  {
    buttonHandler(null, pressedButton);
    pressedButton = null;
  }
  deselectAll();
  stopPaste();
  return true;
}
// Снять выделение
function deselectAll()
{
  for (var i in selectedcards)
  {
    var e = document.getElementById('cardtd_'+i);
    e.className = 'cardtd';
  }
  selectedcards = {};
}
// Обработчик, пытающийся по иерархии найти кнопку (id=btn_*),
// и вызвать на ней buttonHandler
function guessButton(ev)
{
  ev = DragMaster.fixEvent(ev);
  var t;
  if (t = searchButtonTarget(ev))
    return buttonHandler(ev, t);
  return true;
}
// Обработчик mousedown и mouseup на кнопках (id=btn_*)
function buttonHandler(ev, target)
{
  if (!pressedButton)
  {
    pressedButton = target;
    target.style.borderStyle = 'inset';
    target.style.padding = '4px 2px 2px 4px';
  }
  else if (pressedButton == target)
  {
    target.style.borderStyle = 'outset';
    target.style.padding = '3px';
    pressedButton = null;
    if (target.id == 'btn_cut')
      deleteSelectedCards(true);
    else if (target.id == 'btn_delete')
      deleteSelectedCards(false);
    else if (target.id == 'btn_paste')
      pasteCards();
    else if (target.id == 'btn_paste_beg')
      doPasteCards(0);
    return true;
  }
  return false;
}
// Обработчик клика-выделения по карточке
function selectCard(ev, target)
{
  var empty = isEmptyHash(selectedcards, target.id.substr(7));
  if (pasteMode)
  {
    doPasteCards(id_to_coord(target.id)+1);
    return true;
  }
  else if (ctrl || !selectedcards[target.id.substr(7)])
  {
    if (!ctrl)
      deselectAll();
    var issel = target.className == 'cardtd selected';
    target.className = issel ? 'cardtd' : 'cardtd selected';
    if (issel)
      delete selectedcards[target.id.substr(7)];
    else
      selectedcards[target.id.substr(7)] = true;
    return true;
  }
  return false;
}
// Подсветка карточки в режиме вставки
function highlightCard(ev)
{
  if (pasteMode)
  {
    ev = DragMaster.fixEvent(ev);
    var t = searchCardTarget(ev);
    t.className = 'cardtd highlight';
    highlitCard = t;
  }
}
// Снятие подсветки карточки в режиме вставки
function unlightCard(ev)
{
  if (pasteMode)
  {
    ev = DragMaster.fixEvent(ev);
    var t = searchCardTarget(ev);
    t.className = 'cardtd';
  }
}
// Преобразование номера в координаты [лист, строка, столбец]
function to_coord(i)
{
  var to_k = Math.floor(i / nr / nc);
  var to_i = Math.floor((i / nc) % nr);
  var to_j = Math.floor(i % nc);
  return [to_k, to_i, to_j];
}
// Преобразование id элемента (.*лист_строка_столбец.*) в номер
function id_to_coord(id)
{
  var m = /(\d+)_(\d+)_(\d+)/.exec(id.substr(7));
  return (parseInt(m[1])*nr+parseInt(m[2]))*nc+parseInt(m[3]);
}
// Удалить(cut=0)/вырезать(cut=1) выделенные карточки
function deleteSelectedCards(cut)
{
  var shift = 0;
  var coord = 0;
  var n = nr * nc * np;
  if (cut)
  {
    cuttedcards = [];
    cuttedids = [];
  }
  for (var k = 0; k < np; k++)
  {
    for (var i = 0; i < nr; i++)
    {
      for (var j = 0; j < nc; j++, coord++)
      {
        var s = selectedcards[k+'_'+i+'_'+j];
        var e = document.getElementById('cardtd_'+k+'_'+i+'_'+j);
        if (s)
        {
          if (cut)
          {
            cuttedcards.push(e.innerHTML);
            cuttedids.push(idlist[coord]);
          }
          shift++;
        }
        else if (shift > 0)
        {
          var to = to_coord(coord-shift);
          document.getElementById('cardtd_'+to[0]+'_'+to[1]+'_'+to[2]).innerHTML = e.innerHTML;
          idlist[coord-shift] = idlist[coord];
        }
        else if (coord + shift < n)
          continue;
        // во всех трёх случаях - если выделена для
        // удаления, если перемещена в другую, или
        // если находится в конце - очищаем
        e.innerHTML = emptycell;
        idlist[coord] = '';
      }
    }
  }
  if (cut && cuttedids.length)
    document.getElementById('cut_status').innerHTML = 'Вырезано '+cuttedids.length+' карточек.';
  deselectAll();
  document.getElementById('idlist_value').value = idlist.join(',');
}
// Перейти в режим выбора места вставки вырезанных карточек
function pasteCards()
{
  if (!pasteMode)
  {
    if (!cuttedids.length)
    {
      alert('Сначала выделите и вырежьте какие-нибудь карточки!');
      return;
    }
    alert('Кликните на карточку, после которой нужно вставить вырезанное, либо на кнопку "В начало".');
    deselectAll();
    pasteMode = true;
    document.getElementById('btn_paste_beg').style.display = '';
  }
}
// Вставить вырезанные карточки в позицию coord
function doPasteCards(coord)
{
  stopPaste();
  var nx = cuttedids.length;
  if (nx <= 0)
    return;
  var n = nr * nc * np;
  var from, to;
  for (var i = n-nx-1; i >= coord; i--)
  {
    from = to_coord(i);
    to = to_coord(i+nx);
    document.getElementById('cardtd_'+to[0]+'_'+to[1]+'_'+to[2]).innerHTML =
      document.getElementById('cardtd_'+from[0]+'_'+from[1]+'_'+from[2]).innerHTML;
    idlist[i+nx] = idlist[i];
  }
  for (var i = 0; i < nx; i++)
  {
    to = to_coord(i+coord);
    document.getElementById('cardtd_'+to[0]+'_'+to[1]+'_'+to[2]).innerHTML = cuttedcards[i];
    document.getElementById('cardtd_'+to[0]+'_'+to[1]+'_'+to[2]).className = 'cardtd selected';
    idlist[i+coord] = cuttedids[i];
    selectedcards[to[0]+'_'+to[1]+'_'+to[2]] = true;
  }
  cuttedids = [];
  cuttedcards = [];
  document.getElementById('cut_status').innerHTML = '';
  document.getElementById('idlist_value').value = idlist.join(',');
}
// Выйти из режима вставки
function stopPaste()
{
  if (highlitCard)
    highlitCard.className = 'cardtd';
  document.getElementById('btn_paste_beg').style.display = 'none';
  pasteMode = false;
}
// Обработчик keydown/keyup, записывает состояние ctrl
function ctrlDown(ev)
{
  if (ev.keyCode == 17)
  {
    ctrl = ev.type == 'keydown';
    return true;
  }
  return false;
}
// Попробовать найти по иерархии карточку (id=cardtd_*)
function searchCardTarget(e)
{
  var nt = e._target, i;
  while (nt && (!nt.attributes ||
    !(i = nt.attributes.getNamedItem('id')) ||
    i.value.substr(0, 7) != 'cardtd_'))
    nt = nt.parentNode;
  return nt;
}
// Попробовать найти по иерархии кнопку (id=btn_*)
function searchButtonTarget(e)
{
  var nt = e._target, i;
  while (nt && (!nt.attributes ||
    !(i = nt.attributes.getNamedItem('id')) ||
    i.value.substr(0, 4) != 'btn_'))
    nt = nt.parentNode;
  return nt;
}
// Попробовать найти по иерархии что-нибудь кроме карточек и кнопок,
// по сути это только <input> и <textarea>, клик по чему не сбрасывает всё нахрен
function searchNonResetTarget(e)
{
  var nt = e._target, i;
  while (nt && (!(i = nt.nodeName.toLowerCase()) ||
    !(i == 'input' || i == 'textarea')))
    nt = nt.parentNode;
  return nt;
}
// Глобальный обработчик события mouseup
function mouseUpHandler(e)
{
  e = DragMaster.fixEvent(e);
  var t;
  if (searchNonResetTarget(e)) {}
  else if (t = searchCardTarget(e))
    selectCard(e, t);
  else if (t = searchButtonTarget(e))
    buttonHandler(e, t);
  else
    resetAll();
  return true;
}
// Класс "Перетаскиваемая карточка", унаследованный от "Перетаскиваемого объекта"
// Логика - при начале перетаскивания удаляется из родительского элемента,
// который есть строка таблицы, и вместо себя вставляет пустую ячейку.
// При окончании перетаскивания сначала возвращается на место, а потом дёргает
// обработчики вырезания и вставки карточек.
var CardDragObject = function(e)
{
  DragObject.call(this, e);
  this.n = id_to_coord(e.id);
};
CardDragObject.prototype = new DragObject();
CardDragObject.prototype.onDragStart = function() {
  this.tmp = document.createElement('td');
  this.element.style.opacity = 0.5;
  this.element.parentNode.insertBefore(this.tmp, this.element);
  this.element.parentNode.parentNode.parentNode.appendChild(this.element);
};
CardDragObject.prototype.onDragSuccess = function(target, pos) {
  this.tmp.parentNode.insertBefore(this.element, this.tmp);
  this.tmp.parentNode.removeChild(this.tmp);
  if (!selectedcards[this.element.id.substr(7)])
  {
    deselectAll();
    selectedcards[this.element.id.substr(7)] = true;
  }
  deleteSelectedCards(true);
  var to = id_to_coord(target.element.id);
  if (to < this.n)
    to++;
  var w = target.element.scrollWidth;
  if (pos.x < w/2 && to > 0)
    to--;
  doPasteCards(to);
};
CardDragObject.prototype.onDragFail = function() {
  this.tmp.parentNode.insertBefore(this.element, this.tmp);
  this.tmp.parentNode.removeChild(this.tmp);
};
// Каждая карточка также является целью перетаскивания
// Тут вся логика - подсветить левый/правый край в зависимости
// от положения мышки
var CardDropTarget = function(e)
{
  DropTarget.call(this, e);
  this.n = id_to_coord(e.id);
};
CardDropTarget.prototype = new DropTarget();
CardDropTarget.prototype.onLeave = function()
{
  this.element.style.border = '';
};
CardDropTarget.prototype.onMove = function(pos)
{
  var w = this.element.scrollWidth;
  if (pos.x < w/2)
  {
    this.element.style.borderLeft = '5px solid red';
    this.element.style.borderRight = '';
  }
  else
  {
    this.element.style.borderLeft = '';
    this.element.style.borderRight = '5px solid red';
  }
};
// Универсальное добавление обработчика события
var addListener = function() {
  if (window.addEventListener) {
    return function(el, type, fn) { el.addEventListener(type, fn, false); };
  } else if (window.attachEvent) {
    return function(el, type, fn) {
      var f = function() { return fn.call(el, window.event); };
      el.attachEvent('on'+type, f);
    };
  } else {
    return function(el, type, fn) { element['on'+type] = fn; }
  }
}();
// 2 если hash пуст
// 1 если в нём один ключ key
// 0 если в нём есть ключ, не равный key
function isEmptyHash(hash, key)
{
  var empty = 2;
  for (var i in hash)
  {
    if (key !== undefined && i == key)
      empty = 1;
    else
    {
      empty = 0;
      break;
    }
  }
  return empty;
}
// Установка обработчиков событий:
for (var k = 0; k < np; k++)
{
  for (var i = 0; i < nr; i++)
  {
    for (var j = 0; j < nc; j++)
    {
      var e = document.getElementById('cardtd_'+k+'_'+i+'_'+j);
      addListener(e, 'mouseover', highlightCard);
      addListener(e, 'mouseout', unlightCard);
      new CardDragObject(e);
      new CardDropTarget(e);
    }
  }
}
addListener(document, "mousedown", guessButton);
addListener(document, "mouseup", mouseUpHandler);
addListener(document, "keydown", ctrlDown);
addListener(document.getElementById('addbugs'), "keypress", addNewIfEnter);
addListener(document, "keyup", ctrlDown);
