/* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is the Bugzilla Bug Tracking System.
 *
 * The Initial Developer of the Original Code is Netscape Communications
 * Corporation.
 * Portions created by the Initial Developer are Copyright (C) 2009
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *  Myk Melez <myk@mozilla.org>
 *  Frédéric Buclin <LpSolit@gmail.com>
 *
 * ***** END LICENSE BLOCK ***** */

// Enables or disables a requestee field depending on whether or not
// the user is requesting the corresponding flag.
function toggleRequesteeField(flagField, no_focus)
{
    // Convert the ID of the flag field into the ID of its corresponding
    // requestee field and then use the ID to get the field.
    var id = flagField.name.replace(/flag(_type)?-(\d+)/, "requestee$1-$2");
    var requesteeField = document.getElementById(id);
    if (!requesteeField)
        return;

    // Enable or disable the requestee field based on the value
    // of the flag field.
    if (flagField.value == "?")
    {
        requesteeField.disabled = flagField.disabled;
        if (!no_focus && !requesteeField.disabled)
            requesteeField.focus();
    }
    else
        requesteeField.disabled = true;
}

// Disables requestee fields when the window is loaded since they shouldn't
// be enabled until the user requests that flag type.
function disableRequesteeFields()
{
    var inputElements = document.getElementsByTagName("input");
    var selectElements = document.getElementsByTagName("select");
    // You cannot update Node lists, so you must create an array to combine the NodeLists
    var allElements = [];
    for (var i = 0; i < inputElements.length; i++)
        allElements.push(inputElements.item(i));
    // Combine inputs with selects
    for (var i = 0; i < selectElements.length; i++)
        allElements.push(selectElements.item(i));
    var inputElement, id, flagField;
    for (var i = 0; i < allElements.length; i++)
    {
        inputElement = allElements[i];
        if (inputElement.name.search(/^requestee(_type)?-(\d+)$/) != -1)
        {
            // Convert the ID of the requestee field into the ID of its corresponding
            // flag field and then use the ID to get the field.
            id = inputElement.name.replace(/requestee(_type)?-(\d+)/, "flag$1-$2");
            flagField = document.getElementById(id);
            if (flagField && flagField.value != "?")
            {
                inputElement.disabled = true;
                // For combo-boxes
                inputElement = document.getElementById(inputElement.id+'_s');
                if (inputElement)
                    inputElement.disabled = true;
            }
        }
    }
}

onDomReady(disableRequesteeFields);
