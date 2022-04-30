import module namespace dlog ="http://kitwallace.me/lib/dlog" at "lib/dlog-2.xqm";
let $devices := dlog:devices()
for $device in $devices[alert-interval][active]  
let $deviceid := $device/id
let $log := dlog:log($deviceid)  
let $last := $log/record[last()]
let $last-time := xs:dateTime($last/ts)
let $alert-time := xs:dateTime($device/alert-time)
let $hours-since-last-update := floor((current-dateTime() - $last-time) div xs:dayTimeDuration("PT1H"))
let $hours_since-last-alert:=  floor((current-dateTime() - $alert-time) div xs:dayTimeDuration("PT1H"))
let $next-alert-interval :=  xs:integer(($device/next-alert-interval,$device/alert-interval)[1])
let $login := xmldb:login("/db/apps/logger","admin","perdika")
   
return
   if ((empty($device/alert-time) or $hours_since-last-alert  > $next-alert-interval)
        and $hours-since-last-update  > $device/alert-interval)
   then
       let $send-emails :=
            for $email in $device/device-alert-email
            let $message := 
  <mail>
   <from>kit@bristoltrees.space</from>
   <to>{$email}</to>
   <subject>Device {$device/id/string()} : {$device/name/string()} not reporting </subject>
   <message>
     <xhtml><div>
              Device {$device/id/string()} : {$device/name/string()} has not reported for {$hours-since-last-update} hours.   <br/>
             
              For further information see <a href="{$dlog:root}dashboard.xq?deviceid={$deviceid}&amp;mode=graph">sensor details</a>  <br/> 
              You will be alerted again in {$next-alert-interval} hours.
            </div>
     </xhtml>
   </message>
  </mail>
 
          return mail:send-email($message,(),())
    let $alert-sent-update := 
          if ($device/alert-time) 
          then update replace $device/alert-time with element alert-time {current-dateTime()}
          else update insert element alert-time {current-dateTime()} into $device
    return $send-emails
    
     
    else if (empty($device/alert-time) or $hours_since-last-alert > $next-alert-interval)
    then 
      for $field in $device//field
      let $val := $last/*[name(.)=$field/id]
      let $field-def := dlog:field(($field/tag,$field/id)[1])
      let $trigger := $field/trigger
      let $min :=   ($trigger/min, $field-def/min)[1]
      let $max :=   ($trigger/max, $field-def/max)[1]
      let $below-min := (exists ($min) and number($val) < $min) 
      let $above-max := (exists ($max) and number($val) > $max)
      where $below-min or $above-max 
      return
      let $field-def := dlog:fields()[id=$field/id]
      let $warning := if ($below-min) then concat($field-def/title," reading ", $val," is below the level of ",$min,". ",$trigger[min]/warning)
                      else if ($above-max) then  concat($field-def/title," reading ",$val," is above the level of ",$max,". ",$trigger[max]/warning)
                      else ()

      let $send-emails :=
            for $email in  (if ($trigger/email) then $trigger/email else $device/device-alert-email)
            let $message := 
  <mail>
   <from>kit@bristoltrees.space</from>
   <to>{$email}</to>
   <subject>Device {$device/id/string()} : {$device/name/string()} alert </subject>
   <message>
     <xhtml><div>
              Device {$device/id/string()} : {$device/name/string()} : {$warning} <br/>
              For further information see <a href="{$dlog:root}dashboard.xq?deviceid={$deviceid}&amp;mode=graph">sensor details</a>  <br/> 
              You will be alerted again in {$next-alert-interval} hours.
             
            </div>
     </xhtml>
   </message>
  </mail>
 
          return mail:send-email($message,(),())
          
    let $alert-sent-update := 
          if ($device/alert-time) 
          then update replace $device/alert-time with element alert-time {current-dateTime()}
          else update insert element alert-time {current-dateTime()} into $device
    return $send-emails

   else ()
