/**
 * Calendar Script, slightly modified
 * Creates a calendar widget which can be used to select the date more easily than using just a text box
 * http://www.openjs.com/scripts/ui/calendar/
 * License: MIT-like, http://www.openjs.com/license.php
 *
 * Example:
 * <input type="text" name="date" id="date" />
 * <script type="text/javascript">
 *     Calendar.set("date");
 * </script>
 */
var Calendar = {
    month_names: ["January","February","March","April","May","June","July","Augest","September","October","November","December"],
    weekdays: ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"],
    sunday: 0,
    month_days: [31,28,31,30,31,30,31,31,30,31,30,31],
    //Get today's date - year, month, day and date
    today : new Date(),
    opt : {},
    data: [],
    addedListener : false,


    //Functions
    /// Used to create HTML in a optimized way.
    wrt:function(txt) {
        this.data.push(txt);
    },

    getPosition:function(ele) {
        var x = 0;
        var y = 0;
        while (ele) {
            x += ele.offsetLeft;
            y += ele.offsetTop;
            ele = ele.offsetParent;
        }
        if (navigator.userAgent.indexOf("Mac") != -1 && typeof document.body.leftMargin != "undefined") {
            x += document.body.leftMargin;
            offsetTop += document.body.topMargin;
        }

        var xy = new Array(x,y);
        return xy;
    },
    /// Called when the user clicks on a date in the calendar.
    selectDate:function(year,month,day) {
        var ths = _calendar_active_instance;
        var i = document.getElementById(ths.opt["input"]);
        var t = i.value.split(/\s+/, 2)[1]||'';
        if (t)
            t = ' '+t;
        i.value = year + "-" + month + "-" + day + t; // Date format is :HARDCODE:
        ths.hideCalendar();
    },
    /// Creates a calendar with the date given in the argument as the selected date.
    makeCalendar:function(year, month, day) {
        year = parseInt(year);
        month= parseInt(month);
        day     = parseInt(day);

        //Display the table
        var next_month = month+1;
        var next_month_year = year;
        if(next_month>=12) {
            next_month = 0;
            next_month_year++;
        }

        var previous_month = month-1;
        var previous_month_year = year;
        if(previous_month<0) {
            previous_month = 11;
            previous_month_year--;
        }

        this.wrt("<table>");
        this.wrt("<tr><th><a href='javascript:Calendar.makeCalendar("+(previous_month_year)+","+(previous_month)+");' title='"+this.month_names[previous_month]+" "+(previous_month_year)+"'>&lt;</a></th>");
        this.wrt("<th colspan='5' class='calendar-title'><select name='calendar-month' class='calendar-month' onChange='Calendar.makeCalendar("+year+",this.value);'>");
        for(var i in this.month_names) {
            this.wrt("<option value='"+i+"'");
            if(i == month) this.wrt(" selected='selected'");
            this.wrt(">"+this.month_names[i]+"</option>");
        }
        this.wrt("</select>");
        this.wrt("<select name='calendar-year' class='calendar-year' onChange='Calendar.makeCalendar(this.value, "+month+");'>");
        var current_year = this.today.getYear();
        if(current_year < 1900) current_year += 1900;

        for(var i=current_year-70; i<current_year+10; i++) {
            this.wrt("<option value='"+i+"'")
            if(i == year) this.wrt(" selected='selected'");
            this.wrt(">"+i+"</option>");
        }
        this.wrt("</select></th>");
        this.wrt("<th><a href='javascript:Calendar.makeCalendar("+(next_month_year)+","+(next_month)+");' title='"+this.month_names[next_month]+" "+(next_month_year)+"'>&gt;</a></th></tr>");
        this.wrt("<tr class='header'>");
        for(var weekday=0; weekday<7; weekday++) this.wrt("<td>"+this.weekdays[weekday]+"</td>");
        this.wrt("</tr>");

        //Get the first day of this month
        var first_day = new Date(year,month,1);
        var start_day = (first_day.getDay()+Calendar.sunday)%7;

        var d = 1;
        var flag = 0;

        //Leap year support
        if(year % 4 == 0) this.month_days[1] = 29;
        else this.month_days[1] = 28;

        var days_in_this_month = this.month_days[month];

        //Create the calender
        for(var i=0;i<=5;i++) {
            if(w >= days_in_this_month) break;
            this.wrt("<tr>");
            for(var j=0;j<7;j++) {
                if(d > days_in_this_month) flag=0; //If the days has overshooted the number of days in this month, stop writing
                else if(j >= start_day && !flag) flag=1;//If the first day of this month has come, start the date writing

                if(flag) {
                    var w = d, mon = month+1;
                    if(w < 10)    w    = "0" + w;
                    if(mon < 10)mon = "0" + mon;

                    //Is it today?
                    var class_name = '';
                    var yea = this.today.getYear();
                    if(yea < 1900) yea += 1900;

                    if(yea == year && this.today.getMonth() == month && this.today.getDate() == d) class_name = " today";
                    if(day == d) class_name += " selected";

                    class_name += " " + this.weekdays[j].toLowerCase();

                    this.wrt("<td class='days"+class_name+"'><a href='javascript:Calendar.selectDate(\""+year+"\",\""+mon+"\",\""+w+"\")'>"+w+"</a></td>");
                    d++;
                } else {
                    this.wrt("<td class='days'>&nbsp;</td>");
                }
            }
            this.wrt("</tr>");
        }
        this.wrt("</table>");
        this.wrt("<input type='button' value='Cancel' class='calendar-cancel' onclick='Calendar.hideCalendar();' />");

        document.getElementById(this.opt['calendar']).innerHTML = this.data.join("");
        this.data = [];
    },

    /// Display the calendar - if a date exists in the input box, that will be selected in the calendar.
    showCalendar: function() {
        var input = document.getElementById(this.opt['input']);

        //Position the div in the correct location...
        var div = document.getElementById(this.opt['calendar']);
        var xy = this.getPosition(input);
        var width = input.clientWidth||input.offsetWidth;
        div.style.left=(xy[0]+width+10)+"px";
        div.style.top=xy[1]+"px";

        // Show the calendar with the date in the input as the selected date
        var existing_date = new Date();
        var date_in_input = input.value.replace(/\s+.*$/, ''); //Remove time
        if(date_in_input) {
            var selected_date = false;
            var date_parts = date_in_input.split("-");
            if(date_parts.length == 3) {
                date_parts[1]--; //Month starts with 0
                selected_date = new Date(date_parts[0], date_parts[1], date_parts[2]);
            }
            if(selected_date && !isNaN(selected_date.getYear())) { //Valid date.
                existing_date = selected_date;
            }
        }

        var the_year = existing_date.getYear();
        if(the_year < 1900) the_year += 1900;
        this.makeCalendar(the_year, existing_date.getMonth(), existing_date.getDate());
        document.getElementById(this.opt['calendar']).style.display = "block";
        _calendar_active_instance = this;

        if (!Calendar.addedListener)
        {
            addListener(div, "mousedown", function(ev) {
                ev = ev || window.event;
                if (ev.stopPropagation)
                    ev.stopPropagation();
                else
                    ev.cancelBubble = true;
                return true;
            });
            addListener(document, "mousedown", function() { Calendar.hideCalendar(); });
            Calendar.addedListener = true;
        }
    },

    /// Hides the currently show calendar.
    hideCalendar: function(instance) {
        var active_calendar_id = "";
        if(instance) active_calendar_id = instance.opt['calendar'];
        else if(!_calendar_active_instance) return;
        else active_calendar_id = _calendar_active_instance.opt['calendar'];

        if(active_calendar_id) document.getElementById(active_calendar_id).style.display = "none";
        _calendar_active_instance = null;
    },

    /// Setup a text input box to be a calendar box.
    set: function(input_id) {
        var input = document.getElementById(input_id);
        if(!input) return; //If the input field is not there, exit.

        if(!this.opt['calendar']) this.init();

        var ths = this;
        addListener(input, 'click', function(ev) {
            ths.opt['input'] = this.id;
            ths.showCalendar();
        });
    },

    /// Will be called once when the first input is set.
    init: function() {
        if(!this.opt['calendar'] || !document.getElementById(this.opt['calendar'])) {
            var div = document.createElement('div');
            if(!this.opt['calendar']) this.opt['calendar'] = 'calender_div_'+ Math.round(Math.random() * 100);

            div.setAttribute('id',this.opt['calendar']);
            div.className="calendar-box";

            document.getElementsByTagName("body")[0].insertBefore(div,document.getElementsByTagName("body")[0].firstChild);
        }
    }
}
