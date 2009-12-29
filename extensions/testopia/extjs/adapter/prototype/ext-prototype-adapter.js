/*
 * Ext JS Library 3.0.0
 * Copyright(c) 2006-2009 Ext JS, LLC
 * licensing@extjs.com
 * http://www.extjs.com/license
 */
window.undefined=window.undefined;Ext={version:"3.0"};Ext.apply=function(d,e,b){if(b){Ext.apply(d,b)}if(d&&e&&typeof e=="object"){for(var a in e){d[a]=e[a]}}return d};(function(){var g=0,t=Object.prototype.toString,s=function(e){if(Ext.isArray(e)||e.callee){return true}if(/NodeList|HTMLCollection/.test(t.call(e))){return true}return((e.nextNode||e.item)&&Ext.isNumber(e.length))},u=navigator.userAgent.toLowerCase(),z=function(e){return e.test(u)},i=document,l=i.compatMode=="CSS1Compat",B=z(/opera/),h=z(/chrome/),v=z(/webkit/),y=!h&&z(/safari/),f=y&&z(/applewebkit\/4/),b=y&&z(/version\/3/),C=y&&z(/version\/4/),r=!B&&z(/msie/),p=r&&z(/msie 7/),o=r&&z(/msie 8/),q=r&&!p&&!o,n=!v&&z(/gecko/),d=n&&z(/rv:1\.8/),a=n&&z(/rv:1\.9/),w=r&&!l,A=z(/windows|win32/),k=z(/macintosh|mac os x/),j=z(/adobeair/),m=z(/linux/),c=/^https/i.test(window.location.protocol);if(q){try{i.execCommand("BackgroundImageCache",false,true)}catch(x){}}Ext.apply(Ext,{SSL_SECURE_URL:"javascript:false",isStrict:l,isSecure:c,isReady:false,enableGarbageCollector:true,enableListenerCollection:false,USE_NATIVE_JSON:false,applyIf:function(D,E){if(D){for(var e in E){if(Ext.isEmpty(D[e])){D[e]=E[e]}}}return D},id:function(e,D){return(e=Ext.getDom(e)||{}).id=e.id||(D||"ext-gen")+(++g)},extend:function(){var D=function(F){for(var E in F){this[E]=F[E]}};var e=Object.prototype.constructor;return function(K,H,J){if(Ext.isObject(H)){J=H;H=K;K=J.constructor!=e?J.constructor:function(){H.apply(this,arguments)}}var G=function(){},I,E=H.prototype;G.prototype=E;I=K.prototype=new G();I.constructor=K;K.superclass=E;if(E.constructor==e){E.constructor=H}K.override=function(F){Ext.override(K,F)};I.superclass=I.supr=(function(){return E});I.override=D;Ext.override(K,J);K.extend=function(F){Ext.extend(K,F)};return K}}(),override:function(e,E){if(E){var D=e.prototype;Ext.apply(D,E);if(Ext.isIE&&E.toString!=e.toString){D.toString=E.toString}}},namespace:function(){var D,e;Ext.each(arguments,function(E){e=E.split(".");D=window[e[0]]=window[e[0]]||{};Ext.each(e.slice(1),function(F){D=D[F]=D[F]||{}})});return D},urlEncode:function(I,H){var F,D=[],E,G=encodeURIComponent;for(E in I){F=!Ext.isDefined(I[E]);Ext.each(F?E:I[E],function(J,e){D.push("&",G(E),"=",(J!=E||!F)?G(J):"")})}if(!H){D.shift();H=""}return H+D.join("")},urlDecode:function(E,D){var H={},G=E.split("&"),I=decodeURIComponent,e,F;Ext.each(G,function(J){J=J.split("=");e=I(J[0]);F=I(J[1]);H[e]=D||!H[e]?F:[].concat(H[e]).concat(F)});return H},urlAppend:function(e,D){if(!Ext.isEmpty(D)){return e+(e.indexOf("?")===-1?"?":"&")+D}return e},toArray:function(){return r?function(e,F,D,E){E=[];Ext.each(e,function(G){E.push(G)});return E.slice(F||0,D||E.length)}:function(e,E,D){return Array.prototype.slice.call(e,E||0,D||e.length)}}(),each:function(G,F,E){if(Ext.isEmpty(G,true)){return}if(!s(G)||Ext.isPrimitive(G)){G=[G]}for(var D=0,e=G.length;D<e;D++){if(F.call(E||G[D],G[D],D,G)===false){return D}}},iterate:function(E,D,e){if(s(E)){Ext.each(E,D,e);return}else{if(Ext.isObject(E)){for(var F in E){if(E.hasOwnProperty(F)){if(D.call(e||E,F,E[F])===false){return}}}}}},getDom:function(e){if(!e||!i){return null}return e.dom?e.dom:(Ext.isString(e)?i.getElementById(e):e)},getBody:function(){return Ext.get(i.body||i.documentElement)},removeNode:r?function(){var e;return function(D){if(D&&D.tagName!="BODY"){e=e||i.createElement("div");e.appendChild(D);e.innerHTML=""}}}():function(e){if(e&&e.parentNode&&e.tagName!="BODY"){e.parentNode.removeChild(e)}},isEmpty:function(D,e){return D===null||D===undefined||((Ext.isArray(D)&&!D.length))||(!e?D==="":false)},isArray:function(e){return t.apply(e)==="[object Array]"},isObject:function(e){return e&&typeof e=="object"},isPrimitive:function(e){return Ext.isString(e)||Ext.isNumber(e)||Ext.isBoolean(e)},isFunction:function(e){return t.apply(e)==="[object Function]"},isNumber:function(e){return typeof e==="number"&&isFinite(e)},isString:function(e){return typeof e==="string"},isBoolean:function(e){return typeof e==="boolean"},isDefined:function(e){return typeof e!=="undefined"},isOpera:B,isWebKit:v,isChrome:h,isSafari:y,isSafari3:b,isSafari4:C,isSafari2:f,isIE:r,isIE6:q,isIE7:p,isIE8:o,isGecko:n,isGecko2:d,isGecko3:a,isBorderBox:w,isLinux:m,isWindows:A,isMac:k,isAir:j});Ext.ns=Ext.namespace})();Ext.ns("Ext","Ext.util","Ext.lib","Ext.data");Ext.apply(Function.prototype,{createInterceptor:function(b,a){var c=this;return !Ext.isFunction(b)?this:function(){var e=this,d=arguments;b.target=e;b.method=c;return(b.apply(a||e||window,d)!==false)?c.apply(e||window,d):null}},createCallback:function(){var a=arguments,b=this;return function(){return b.apply(window,a)}},createDelegate:function(c,b,a){var d=this;return function(){var f=b||arguments;if(a===true){f=Array.prototype.slice.call(arguments,0);f=f.concat(b)}else{if(Ext.isNumber(a)){f=Array.prototype.slice.call(arguments,0);var e=[a,0].concat(b);Array.prototype.splice.apply(f,e)}}return d.apply(c||window,f)}},defer:function(c,e,b,a){var d=this.createDelegate(e,b,a);if(c>0){return setTimeout(d,c)}d();return 0}});Ext.applyIf(String,{format:function(b){var a=Ext.toArray(arguments,1);return b.replace(/\{(\d+)\}/g,function(c,d){return a[d]})}});Ext.applyIf(Array.prototype,{indexOf:function(c){for(var b=0,a=this.length;b<a;b++){if(this[b]==c){return b}}return -1},remove:function(b){var a=this.indexOf(b);if(a!=-1){this.splice(a,1)}return this}});Ext.ns("Ext.grid","Ext.dd","Ext.tree","Ext.form","Ext.menu","Ext.state","Ext.layout","Ext.app","Ext.ux","Ext.chart","Ext.direct");Ext.apply(Ext,function(){var b=Ext,a=0;return{emptyFn:function(){},BLANK_IMAGE_URL:Ext.isIE6||Ext.isIE7?"http://extjs.com/s.gif":"data:image/gif;base64,R0lGODlhAQABAID/AMDAwAAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==",extendX:function(c,d){return Ext.extend(c,d(c.prototype))},getDoc:function(){return Ext.get(document)},isDate:function(c){return Object.prototype.toString.apply(c)==="[object Date]"},num:function(d,c){d=Number(d===null||typeof d=="boolean"?NaN:d);return isNaN(d)?c:d},value:function(e,c,d){return Ext.isEmpty(e,d)?c:e},escapeRe:function(c){return c.replace(/([.*+?^${}()|[\]\/\\])/g,"\\$1")},sequence:function(f,c,e,d){f[c]=f[c].createSequence(e,d)},addBehaviors:function(g){if(!Ext.isReady){Ext.onReady(function(){Ext.addBehaviors(g)})}else{var d={},f,c,e;for(c in g){if((f=c.split("@"))[1]){e=f[0];if(!d[e]){d[e]=Ext.select(e)}d[e].on(f[1],g[c])}}d=null}},combine:function(){var e=arguments,d=e.length,g=[];for(var f=0;f<d;f++){var c=e[f];if(Ext.isArray(c)){g=g.concat(c)}else{if(c.length!==undefined&&!c.substr){g=g.concat(Array.prototype.slice.call(c,0))}else{g.push(c)}}}return g},copyTo:function(c,d,e){if(typeof e=="string"){e=e.split(/[,;\s]/)}Ext.each(e,function(f){if(d.hasOwnProperty(f)){c[f]=d[f]}},this);return c},destroy:function(){Ext.each(arguments,function(c){if(c){if(Ext.isArray(c)){this.destroy.apply(this,c)}else{if(Ext.isFunction(c.destroy)){c.destroy()}else{if(c.dom){c.remove()}}}}},this)},destroyMembers:function(j,g,e,f){for(var h=1,d=arguments,c=d.length;h<c;h++){Ext.destroy(j[d[h]]);delete j[d[h]]}},clean:function(c){var d=[];Ext.each(c,function(e){if(!!e){d.push(e)}});return d},unique:function(c){var d=[],e={};Ext.each(c,function(f){if(!e[f]){d.push(f)}e[f]=true});return d},flatten:function(c){var e=[];function d(f){Ext.each(f,function(g){if(Ext.isArray(g)){d(g)}else{e.push(g)}});return e}return d(c)},min:function(c,d){var e=c[0];d=d||function(g,f){return g<f?-1:1};Ext.each(c,function(f){e=d(e,f)==-1?e:f});return e},max:function(c,d){var e=c[0];d=d||function(g,f){return g>f?1:-1};Ext.each(c,function(f){e=d(e,f)==1?e:f});return e},mean:function(c){return Ext.sum(c)/c.length},sum:function(c){var d=0;Ext.each(c,function(e){d+=e});return d},partition:function(c,d){var e=[[],[]];Ext.each(c,function(g,h,f){e[(d&&d(g,h,f))||(!d&&g)?0:1].push(g)});return e},invoke:function(c,d){var f=[],e=Array.prototype.slice.call(arguments,2);Ext.each(c,function(g,h){if(g&&typeof g[d]=="function"){f.push(g[d].apply(g,e))}else{f.push(undefined)}});return f},pluck:function(c,e){var d=[];Ext.each(c,function(f){d.push(f[e])});return d},zip:function(){var l=Ext.partition(arguments,function(i){return !Ext.isFunction(i)}),g=l[0],k=l[1][0],c=Ext.max(Ext.pluck(g,"length")),f=[];for(var h=0;h<c;h++){f[h]=[];if(k){f[h]=k.apply(k,Ext.pluck(g,h))}else{for(var e=0,d=g.length;e<d;e++){f[h].push(g[e][h])}}}return f},getCmp:function(c){return Ext.ComponentMgr.get(c)},useShims:b.isIE6||(b.isMac&&b.isGecko2),type:function(d){if(d===undefined||d===null){return false}if(d.htmlElement){return"element"}var c=typeof d;if(c=="object"&&d.nodeName){switch(d.nodeType){case 1:return"element";case 3:return(/\S/).test(d.nodeValue)?"textnode":"whitespace"}}if(c=="object"||c=="function"){switch(d.constructor){case Array:return"array";case RegExp:return"regexp";case Date:return"date"}if(typeof d.length=="number"&&typeof d.item=="function"){return"nodelist"}}return c},intercept:function(f,c,e,d){f[c]=f[c].createInterceptor(e,d)},callback:function(c,f,e,d){if(Ext.isFunction(c)){if(d){c.defer(d,f,e||[])}else{c.apply(f,e||[])}}}}}());Ext.apply(Function.prototype,{createSequence:function(b,a){var c=this;return !Ext.isFunction(b)?this:function(){var d=c.apply(this||window,arguments);b.apply(a||this||window,arguments);return d}}});Ext.applyIf(String,{escape:function(a){return a.replace(/('|\\)/g,"\\$1")},leftPad:function(d,b,c){var a=String(d);if(!c){c=" "}while(a.length<b){a=c+a}return a}});String.prototype.toggle=function(b,a){return this==b?a:b};String.prototype.trim=function(){var a=/^\s+|\s+$/g;return function(){return this.replace(a,"")}}();Date.prototype.getElapsed=function(a){return Math.abs((a||new Date()).getTime()-this.getTime())};Ext.applyIf(Number.prototype,{constrain:function(b,a){return Math.min(Math.max(this,b),a)}});Ext.util.TaskRunner=function(e){e=e||10;var f=[],a=[],b=0,g=false,d=function(){g=false;clearInterval(b);b=0},h=function(){if(!g){g=true;b=setInterval(i,e)}},c=function(j){a.push(j);if(j.onStop){j.onStop.apply(j.scope||j)}},i=function(){var l=a.length,n=new Date().getTime();if(l>0){for(var p=0;p<l;p++){f.remove(a[p])}a=[];if(f.length<1){d();return}}for(var p=0,o,k,m,j=f.length;p<j;++p){o=f[p];k=n-o.taskRunTime;if(o.interval<=k){m=o.run.apply(o.scope||o,o.args||[++o.taskRunCount]);o.taskRunTime=n;if(m===false||o.taskRunCount===o.repeat){c(o);return}}if(o.duration&&o.duration<=(n-o.taskStartTime)){c(o)}}};this.start=function(j){f.push(j);j.taskStartTime=new Date().getTime();j.taskRunTime=0;j.taskRunCount=0;h();return j};this.stop=function(j){c(j);return j};this.stopAll=function(){d();for(var k=0,j=f.length;k<j;k++){if(f[k].onStop){f[k].onStop()}}f=[];a=[]}};Ext.TaskMgr=new Ext.util.TaskRunner();(function(){var h,i=Prototype.Version.split("."),a=(parseInt(i[0])>=2)||(parseInt(i[1])>=7)||(parseInt(i[2])>=1),j={},c=Ext.isGecko?function(k){return Object.prototype.toString.call(k)=="[object XULElement]"}:function(){},b=Ext.isGecko?function(k){try{return k.nodeType==3}catch(l){return false}}:function(k){return k.nodeType==3},e=function(k,m){if(k&&k.firstChild){while(m){if(m===k){return true}try{m=m.parentNode}catch(l){return false}if(m&&(m.nodeType!=1)){m=null}}}return false},g=function(l){var k=Ext.lib.Event.getRelatedTarget(l);return !(c(k)||e(l.currentTarget,k))};Ext.lib.Dom={getViewWidth:function(k){return k?this.getDocumentWidth():this.getViewportWidth()},getViewHeight:function(k){return k?this.getDocumentHeight():this.getViewportHeight()},getDocumentHeight:function(){var k=(document.compatMode!="CSS1Compat")?document.body.scrollHeight:document.documentElement.scrollHeight;return Math.max(k,this.getViewportHeight())},getDocumentWidth:function(){var k=(document.compatMode!="CSS1Compat")?document.body.scrollWidth:document.documentElement.scrollWidth;return Math.max(k,this.getViewportWidth())},getViewportHeight:function(){var k=self.innerHeight;var l=document.compatMode;if((l||Ext.isIE)&&!Ext.isOpera){k=(l=="CSS1Compat")?document.documentElement.clientHeight:document.body.clientHeight}return k},getViewportWidth:function(){var k=self.innerWidth;var l=document.compatMode;if(l||Ext.isIE){k=(l=="CSS1Compat")?document.documentElement.clientWidth:document.body.clientWidth}return k},isAncestor:function(l,m){l=Ext.getDom(l);m=Ext.getDom(m);if(!l||!m){return false}if(l.contains&&!Ext.isSafari){return l.contains(m)}else{if(l.compareDocumentPosition){return !!(l.compareDocumentPosition(m)&16)}else{var k=m.parentNode;while(k){if(k==l){return true}else{if(!k.tagName||k.tagName.toUpperCase()=="HTML"){return false}}k=k.parentNode}return false}}},getRegion:function(k){return Ext.lib.Region.getRegion(k)},getY:function(k){return this.getXY(k)[1]},getX:function(k){return this.getXY(k)[0]},getXY:function(m){var l,r,t,u,q=(document.body||document.documentElement);m=Ext.getDom(m);if(m==q){return[0,0]}if(m.getBoundingClientRect){t=m.getBoundingClientRect();u=f(document).getScroll();return[Math.round(t.left+u.left),Math.round(t.top+u.top)]}var v=0,s=0;l=m;var k=f(m).getStyle("position")=="absolute";while(l){v+=l.offsetLeft;s+=l.offsetTop;if(!k&&f(l).getStyle("position")=="absolute"){k=true}if(Ext.isGecko){r=f(l);var w=parseInt(r.getStyle("borderTopWidth"),10)||0;var n=parseInt(r.getStyle("borderLeftWidth"),10)||0;v+=n;s+=w;if(l!=m&&r.getStyle("overflow")!="visible"){v+=n;s+=w}}l=l.offsetParent}if(Ext.isSafari&&k){v-=q.offsetLeft;s-=q.offsetTop}if(Ext.isGecko&&!k){var o=f(q);v+=parseInt(o.getStyle("borderLeftWidth"),10)||0;s+=parseInt(o.getStyle("borderTopWidth"),10)||0}l=m.parentNode;while(l&&l!=q){if(!Ext.isOpera||(l.tagName!="TR"&&f(l).getStyle("display")!="inline")){v-=l.scrollLeft;s-=l.scrollTop}l=l.parentNode}return[v,s]},setXY:function(k,l){k=Ext.fly(k,"_setXY");k.position();var m=k.translatePoints(l);if(l[0]!==false){k.dom.style.left=m.left+"px"}if(l[1]!==false){k.dom.style.top=m.top+"px"}},setX:function(l,k){this.setXY(l,[k,false])},setY:function(k,l){this.setXY(k,[false,l])}};Ext.lib.Event={getPageX:function(k){return Event.pointerX(k.browserEvent||k)},getPageY:function(k){return Event.pointerY(k.browserEvent||k)},getXY:function(k){k=k.browserEvent||k;return[Event.pointerX(k),Event.pointerY(k)]},getTarget:function(k){return Event.element(k.browserEvent||k)},resolveTextNode:function(k){return k&&!c(k)&&b(k)?k.parentNode:k},getRelatedTarget:function(l){l=l.browserEvent||l;var k=l.relatedTarget;if(!k){if(l.type=="mouseout"){k=l.toElement}else{if(l.type=="mouseover"){k=l.fromElement}}}return this.resolveTextNode(k)},on:function(m,k,l){if((k=="mouseenter"||k=="mouseleave")&&!a){var n=j[m.id]||(j[m.id]={});n[k]=l;l=l.createInterceptor(g);k=(k=="mouseenter")?"mouseover":"mouseout"}Event.observe(m,k,l,false)},un:function(m,k,l){if((k=="mouseenter"||k=="mouseleave")&&!a){var o=j[m.id],n=o&&o[k];if(n){l=n.fn;delete o[k];k=(k=="mouseenter")?"mouseover":"mouseout"}}Event.stopObserving(m,k,l,false)},purgeElement:function(k){},preventDefault:function(k){k=k.browserEvent||k;if(k.preventDefault){k.preventDefault()}else{k.returnValue=false}},stopPropagation:function(k){k=k.browserEvent||k;if(k.stopPropagation){k.stopPropagation()}else{k.cancelBubble=true}},stopEvent:function(k){Event.stop(k.browserEvent||k)},onAvailable:function(p,l,k){var o=new Date(),n;var m=function(){if(o.getElapsed()>10000){clearInterval(n)}var q=document.getElementById(p);if(q){clearInterval(n);l.call(k||window,q)}};n=setInterval(m,50)}};Ext.lib.Ajax=function(){var l=function(m){return m.success?function(n){m.success.call(m.scope||window,{responseText:n.responseText,responseXML:n.responseXML,argument:m.argument})}:Ext.emptyFn};var k=function(m){return m.failure?function(n){m.failure.call(m.scope||window,{responseText:n.responseText,responseXML:n.responseXML,argument:m.argument})}:Ext.emptyFn};return{request:function(t,q,m,r,n){var s={method:t,parameters:r||"",timeout:m.timeout,onSuccess:l(m),onFailure:k(m)};if(n){var p=n.headers;if(p){s.requestHeaders=p}if(n.xmlData){t=(t?t:(n.method?n.method:"POST"));if(!p||!p["Content-Type"]){s.contentType="text/xml"}s.postBody=n.xmlData;delete s.parameters}if(n.jsonData){t=(t?t:(n.method?n.method:"POST"));if(!p||!p["Content-Type"]){s.contentType="application/json"}s.postBody=typeof n.jsonData=="object"?Ext.encode(n.jsonData):n.jsonData;delete s.parameters}}new Ajax.Request(q,s)},formRequest:function(q,p,n,r,m,o){new Ajax.Request(p,{method:Ext.getDom(q).method||"POST",parameters:Form.serialize(q)+(r?"&"+r:""),timeout:n.timeout,onSuccess:l(n),onFailure:k(n)})},isCallInProgress:function(m){return false},abort:function(m){return false},serializeForm:function(m){return Form.serialize(m.dom||m)}}}();Ext.lib.Anim=function(){var k={easeOut:function(m){return 1-Math.pow(1-m,2)},easeIn:function(m){return 1-Math.pow(1-m,2)}};var l=function(m,n){return{stop:function(o){this.effect.cancel()},isAnimated:function(){return this.effect.state=="running"},proxyCallback:function(){Ext.callback(m,n)}}};return{scroll:function(p,n,r,s,m,o){var q=l(m,o);p=Ext.getDom(p);if(typeof n.scroll.to[0]=="number"){p.scrollLeft=n.scroll.to[0]}if(typeof n.scroll.to[1]=="number"){p.scrollTop=n.scroll.to[1]}q.proxyCallback();return q},motion:function(p,n,q,r,m,o){return this.run(p,n,q,r,m,o)},color:function(p,n,q,r,m,o){return this.run(p,n,q,r,m,o)},run:function(n,w,s,v,p,y,x){var m={};for(var r in w){switch(r){case"points":var u,A,t=Ext.fly(n,"_animrun");t.position();if(u=w.points.by){var z=t.getXY();A=t.translatePoints([z[0]+u[0],z[1]+u[1]])}else{A=t.translatePoints(w.points.to)}m.left=A.left+"px";m.top=A.top+"px";break;case"width":m.width=w.width.to+"px";break;case"height":m.height=w.height.to+"px";break;case"opacity":m.opacity=String(w.opacity.to);break;default:m[r]=String(w[r].to);break}}var q=l(p,y);q.effect=new Effect.Morph(Ext.id(n),{duration:s,afterFinish:q.proxyCallback,transition:k[v]||Effect.Transitions.linear,style:m});return q}}}();function f(k){if(!h){h=new Ext.Element.Flyweight()}h.dom=k;return h}Ext.lib.Region=function(n,o,k,m){this.top=n;this[1]=n;this.right=o;this.bottom=k;this.left=m;this[0]=m};Ext.lib.Region.prototype={contains:function(k){return(k.left>=this.left&&k.right<=this.right&&k.top>=this.top&&k.bottom<=this.bottom)},getArea:function(){return((this.bottom-this.top)*(this.right-this.left))},intersect:function(p){var n=Math.max(this.top,p.top);var o=Math.min(this.right,p.right);var k=Math.min(this.bottom,p.bottom);var m=Math.max(this.left,p.left);if(k>=n&&o>=m){return new Ext.lib.Region(n,o,k,m)}else{return null}},union:function(p){var n=Math.min(this.top,p.top);var o=Math.max(this.right,p.right);var k=Math.max(this.bottom,p.bottom);var m=Math.min(this.left,p.left);return new Ext.lib.Region(n,o,k,m)},constrainTo:function(k){this.top=this.top.constrain(k.top,k.bottom);this.bottom=this.bottom.constrain(k.top,k.bottom);this.left=this.left.constrain(k.left,k.right);this.right=this.right.constrain(k.left,k.right);return this},adjust:function(n,m,k,o){this.top+=n;this.left+=m;this.right+=o;this.bottom+=k;return this}};Ext.lib.Region.getRegion=function(o){var s=Ext.lib.Dom.getXY(o);var n=s[1];var q=s[0]+o.offsetWidth;var k=s[1]+o.offsetHeight;var m=s[0];return new Ext.lib.Region(n,q,k,m)};Ext.lib.Point=function(k,l){if(Ext.isArray(k)){l=k[1];k=k[0]}this.x=this.right=this.left=this[0]=k;this.y=this.top=this.bottom=this[1]=l};Ext.lib.Point.prototype=new Ext.lib.Region();if(Ext.isIE){function d(){var k=Function.prototype;delete k.createSequence;delete k.defer;delete k.createDelegate;delete k.createCallback;delete k.createInterceptor;window.detachEvent("onunload",d)}window.attachEvent("onunload",d)}})();