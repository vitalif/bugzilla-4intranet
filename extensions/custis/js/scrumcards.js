var pressedButton;
var pasteMode = false;
var ctrl = false;
var highlitCard;
var selectedcards = {};
var cuttedcards = [];
var cuttedids = [];
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
function addEmptyPage()
{
  for (var i = 0; i < nr*nc; i++)
    idlist.push('');
  document.getElementById('idlist_value').value = idlist.join(',');
  document.getElementById('scrumform').submit();
}
function addNewIfEnter(ev)
{
  if (ev.keyCode == 10 || ev.keyCode == 13)
  {
    addNewCards();
    return true;
  }
  return false;
}
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
function deselectAll()
{
  for (var i in selectedcards)
  {
    var e = document.getElementById('cardtd_'+i);
    e.className = 'cardtd';
  }
  selectedcards = {};
}
function guessButton(ev)
{
  exFixEvent(ev);
  var t;
  if (t = searchButtonTarget(ev))
    return buttonHandler(ev, t);
  return true;
}
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
function selectCard(ev, target)
{
  var selectedcards_empty = 2;
  for (var i in selectedcards)
  {
    if (i == target.id.substr(7))
      selectedcards_empty = 1;
    else
    {
      selectedcards_empty = 0;
      break;
    }
  }
  if (pasteMode)
  {
    doPasteCards(id_to_coord(target.id)+1);
    return true;
  }
  else if (ctrl || selectedcards_empty)
  {
    if (selectedcards_empty == 1)
      return true;
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
function highlightCard(ev)
{
  if (pasteMode)
  {
    exFixEvent(ev);
    var t = searchCardTarget(ev);
    t.className = 'cardtd highlight';
    highlitCard = t;
  }
}
function unlightCard(ev)
{
  if (pasteMode)
  {
    exFixEvent(ev);
    var t = searchCardTarget(ev);
    t.className = 'cardtd';
  }
}
function to_coord(i)
{
  var to_k = Math.floor(i / nr / nc);
  var to_i = Math.floor((i / nc) % nr);
  var to_j = Math.floor(i % nc);
  return [to_k, to_i, to_j];
}
function id_to_coord(id)
{
  var m = /(\d+)_(\d+)_(\d+)/.exec(id.substr(7));
  return (parseInt(m[1])*nr+parseInt(m[2]))*nc+parseInt(m[3]);
}
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
function deleteAllCards()
{
  idlist = [];
  document.getElementById('idlist_value').value = idlist.join(',');
  document.getElementById('pages').innerHTML = '';
  document.getElementById('scrumform').submit();
}
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
function stopPaste()
{
  if (highlitCard)
    highlitCard.className = 'cardtd';
  document.getElementById('btn_paste_beg').style.display = 'none';
  pasteMode = false;
}
function ctrlDown(ev)
{
  if (ev.keyCode == 17)
  {
    ctrl = true;
    return true;
  }
  return false;
}
function ctrlUp(ev)
{
  if (ev.keyCode == 17)
  {
    ctrl = false;
    return true;
  }
  return false;
}
function searchCardTarget(e)
{
  var nt = e._target, i;
  while (nt && (!nt.attributes ||
    !(i = nt.attributes.getNamedItem('id')) ||
    i.value.substr(0, 7) != 'cardtd_'))
    nt = nt.parentNode;
  return nt;
}
function searchButtonTarget(e)
{
  var nt = e._target, i;
  while (nt && (!nt.attributes ||
    !(i = nt.attributes.getNamedItem('id')) ||
    i.value.substr(0, 4) != 'btn_'))
    nt = nt.parentNode;
  return nt;
}
function mouseUpHandler(e)
{
  exFixEvent(e);
  var card;
  if (card = searchCardTarget(e))
    selectCard(e, card);
  else if (card = searchButtonTarget(e))
    buttonHandler(e, card);
  else
    resetAll();
}
var CardDragObject = function(e) { DragObject.call(this, e); };
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
  var n = true;
  for (var i in selectedcards)
  {
    n = false;
    break;
  }
  if (n)
    selectedcards[this.element.id.substr(7)] = true;
  deleteSelectedCards(true);
  var to = id_to_coord(target.element.id);
  var w = target.element.scrollWidth;
  if (pos.x < w/4 && to > 0)
    to--;
  else if (pos.x > w*3/4 && to+1 < np*nr*nc)
    to++;
  doPasteCards(to);
};
CardDragObject.prototype.onDragFail = function() {
  this.tmp.parentNode.insertBefore(this.element, this.tmp);
  this.tmp.parentNode.removeChild(this.tmp);
};
var CardDropTarget = function(e)
{
  DropTarget.call(this, e);
  this.n = id_to_coord(e.id);
};
CardDropTarget.prototype = new DropTarget();
CardDropTarget.prototype.onLeave = function()
{
  this.element.style.border = '';
  this.element.className = 'cardtd';
};
CardDropTarget.prototype.onMove = function(pos)
{
  var w = this.element.scrollWidth;
  if (pos.x < w/4 && this.n > 0)
  {
    this.element.style.borderLeft = '5px solid red';
    this.element.className = 'cardtd';
  }
  else if (pos.x > w*3/4 && this.n+1 < np*nr*nc)
  {
    this.element.style.borderRight = '5px solid red';
    this.element.className = 'cardtd';
  }
  else
  {
    this.element.style.border = '';
    this.element.className = 'cardtd highlight';
  }
};
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
var exFixEvent = function(ev)
{
  if (!ev) var ev = window.event;
  var t = ev.target;
  if (!t) t = ev.srcElement;
  if (t && t.nodeType == 3) t = t.parentNode; // Safari bug
  ev._target = t;
  // FIXME можно сюда ещё добавить фиксы из DragDrop::fixEvent
}
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
addListener(document, "keyup", ctrlUp);
