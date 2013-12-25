/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * This Source Code Form is "Incompatible With Secondary Licenses", as
 * defined by the Mozilla Public License, v. 2.0.
 */

function updateCommentPrivacy(checkbox, id) {
    var comment_elem = document.getElementById('comment_text_'+id).parentNode;
    if (checkbox.checked) {
      if (!comment_elem.className.match('bz_private')) {
        comment_elem.className = comment_elem.className.concat(' bz_private');
      }
    }
    else {
      comment_elem.className =
        comment_elem.className.replace(/(\s*|^)bz_private(\s*|$)/, '$2');
    }
}

function goto_add_comments( anchor ){
    anchor =  (anchor || "add_comment");
    // we need this line to expand the comment box
    document.getElementById('comment').focus();
    setTimeout(function(){ 
        document.location.hash = anchor;
        // firefox doesn't seem to keep focus through the anchor change
        document.getElementById('comment').focus();
    },10);
    return false;
}

if (typeof Node == 'undefined') {
    /* MSIE doesn't define Node, so provide a compatibility object */
    window.Node = {
        TEXT_NODE: 3,
        ENTITY_REFERENCE_NODE: 5
    };
}

/* Concatenates all text from element's childNodes. This is used
 * instead of innerHTML because we want the actual text (and
 * innerText is non-standard).
 */
function getText(element) {
    var child, text = "";
    for (var i=0; i < element.childNodes.length; i++) {
        child = element.childNodes[i];
        var type = child.nodeType;
        if (type == Node.TEXT_NODE || type == Node.ENTITY_REFERENCE_NODE) {
            text += child.nodeValue;
        } else {
            /* recurse into nodes of other types */
            text += getText(child);
        }
    }
    return text;
}
