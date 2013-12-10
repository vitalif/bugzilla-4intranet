/* The contents of this file are subject to the Mozilla Public
 * License Version 1.1 (the "License"); you may not use this file
 * except in compliance with the License. You may obtain a copy of
 * the License at http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS
 * IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
 * implied. See the License for the specific language governing
 * rights and limitations under the License.
 *
 * The Original Code is the Bugzilla Bug Tracking System.
 *
 * The Initial Developer of the Original Code is Netscape Communications
 * Corporation. Portions created by Netscape are
 * Copyright (C) 1998 Netscape Communications Corporation. All
 * Rights Reserved.
 *
 * Contributor(s): Frédéric Buclin <LpSolit@gmail.com>
 *                 Max Kanat-Alexander <mkanat@bugzilla.org>
 *                 Edmund Wong <ewong@pw-wspx.org>
 *                 Anthony Pipkin <a.pipkin@yahoo.com>
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
