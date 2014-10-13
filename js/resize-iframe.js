/* Resize parent iframe to fit body
 * License: Dual-license GPL 3.0+ or MPL 1.1+
 * Contributor(s): Vitaliy Filippov <vitalif@mail.ru>
 */

/* Allows to resize parent iframe to ease embedding Bugzilla pages
 * onto pages from other domains. Sends HTML5 postMessage with text
 * "resize(w=WIDTH;h=HEIGHT)" to parent window if loaded with ?_resize=1.
 * Works in IE8+, FF 3+, Opera 9.5+, and Chrome.
 */

resizeParentIframe = function()
{
    if ((/resize/.exec(window.location.hash) ||
      /[&\?]_resize=1/.exec(window.location.href)) && 'postMessage' in parent)
    {
        var w = document.body.scrollWidth;
        var h = document.body.scrollHeight;
        parent.postMessage('resize(w='+w+';h='+h+')', '*');
    }
    return true;
};

if (window.addEventListener)
    window.addEventListener('load', resizeParentIframe, false);
else if (window.attachEvent)
    window.attachEvent('onload', resizeParentIframe);
