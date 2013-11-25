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
