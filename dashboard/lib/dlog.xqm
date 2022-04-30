module namespace dlog = "http://kitwallace.me/lib/dlog";
import module namespace ui="http://kitwallace.me/ui" at "/db/lib/ui.xqm";

declare variable $dlog:root := "https://treecarers.org.uk/";
declare variable $dlog:dbroot := "/db/apps/logger/";
declare variable $dlog:appid := "1418";
declare variable $dlog:alert-job := "log-alerts.xq";
declare variable $dlog:weather-job := "get-weather.xq";
declare variable $dlog:events := doc("../logs/events.xml")/events;
declare variable $dlog:model := doc("../ref/model.xml")/model;
declare variable $dlog:archive-path := "/db/apps/logger/archive";

declare function dlog:decimal-digits($f) {
    dlog:decimal-digits($f,0)
};

declare function dlog:decimal-digits($f,$n) {
    if ($f >= 1)
    then $n
    else dlog:decimal-digits($f * 10 ,$n+1)
};

declare function dlog:devices() {
   doc("../sensors/devices.xml")/devices/device
};
declare function dlog:device($deviceid) {
   dlog:devices()[deviceid=$deviceid]
};

declare function dlog:fields() {
   doc("../sensors/devices.xml")//fieldset/field
};

declare function dlog:field($fieldid) {
   dlog:fields()[id=$fieldid]
};

declare function dlog:log($deviceid) {
   let $logs := collection("/db/apps/logger/logs/")/log[@id=$deviceid]
   return
     element log {
         for $record in $logs/*
         order by $record/ts
         return $record
     }
};

(:~
 : unix time from dateTime
 : @param dateTime
 : @return unix timestamp of the supplied datetime
 :)
 
declare function dlog:dateTime-to-timestamp( $dateTime as xs:dateTime) as xs:integer {
    let $dayZero := xs:dateTime('1970-01-01T00:00:00-00:00')
    return
      ($dateTime - $dayZero) div xs:dayTimeDuration('PT1S')
};

declare function dlog:get-band($v,$bands) { 
   $bands/band[xs:float($v) >= @threshold][1]
};

declare function dlog:schedule-alerts() {
   let $interval := "0 0 * * * ?" (: run every hour :)
   let $remove-old := scheduler:delete-scheduled-job($dlog:alert-job) 
   let $schedule := scheduler:schedule-xquery-cron-job(concat($dlog:dbroot,$dlog:alert-job) ,$interval, $dlog:alert-job)
   return true()
};

declare function dlog:cancel-alerts() {
   scheduler:delete-scheduled-job($dlog:alert-job) 
};

declare function dlog:alert-scheduled() {
   let $jobs := scheduler:get-scheduled-jobs()
   let $update-job := $jobs//scheduler:job[@name=$dlog:alert-job]
   return
     $update-job//state = "NORMAL"
};

declare function dlog:schedule-weather() {
   let $interval := "0 10 0,6,12,18 * * ?" (: run every 6 hours at 10 past the hour :)
   let $remove-old := scheduler:delete-scheduled-job($dlog:weather-job) 
   let $schedule := scheduler:schedule-xquery-cron-job(concat($dlog:dbroot,$dlog:weather-job) ,$interval, $dlog:weather-job)
   return true()
};

declare function dlog:cancel-weather() {
   scheduler:delete-scheduled-job($dlog:weather-job) 
};

declare function dlog:weather-scheduled() {
   let $jobs := scheduler:get-scheduled-jobs()
   let $update-job := $jobs//scheduler:job[@name=$dlog:weather-job]
   return
     $update-job//state = "NORMAL"
};

declare function dlog:admin-page() {
 <div>    
    <h3><a href="?">Index</a> >  Site administration</h3>
       {scheduler:get-scheduled-jobs()}
     <ul>
           
      <li>Alerts :  
          {if(dlog:alert-scheduled())
           then <span> Scheduled <a href="?mode=admin&amp;action=cancel-alerts">Cancel Alert task </a>  </span>
           else  <span> Not Scheduled <a href="?mode=admin&amp;action=schedule-alerts">Start Alert task </a> </span>
          }
     </li>
     <li>Weather extract : 
          {if(dlog:weather-scheduled())
           then  <span> Scheduled <a href="?mode=admin&amp;action=cancel-weather">Cancel Weather task </a> </span>
           else  <span> Not Scheduled <a href="?mode=admin&amp;action=schedule-weather">Start Weather task </a> </span>
          }
     </li>
    </ul>  
 </div>
 
 };

declare function dlog:list-archive($deviceid) {
    let $archives := collection($dlog:archive-path)/log[@id=$deviceid]
    return
    <div>
      <table>
      <tr><th>From</th><th>To</th><th>#records</th></tr>
      {for $archive in $archives
       let $name := util:document-name($archive)
       let $from := $archive/record[1]/ts
       let $to := $archive/record[last()]/ts
       order by $from
       return
        <tr><td><a href="?deviceid={$deviceid}&amp;mode=graph&amp;archive={$name}">{$from}</a></td><td>{$to}</td><td>{count($archive/record)}</td></tr>
        }
      </table>    
    </div>
 };
