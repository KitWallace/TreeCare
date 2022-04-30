import module namespace dlog ="http://kitwallace.me/lib/dlog" at "lib/dlog-2.xqm";

declare function local:convert-moisture($compute,$record) {
    round(($compute/parameter[@id="air"] - $record/moisture) div ($compute/parameter[@id="air"]- $compute/parameter[@id="water"])  * 100 ) 
};

let $request := request:get-query-string()
let $appid := request:get-parameter("_appid",())
let $test-mode := request:get-parameter("_test",())
let $deviceid := request:get-parameter("_device",())
let $MAC :=  request:get-parameter("_MAC",())
let $device := if (exists($deviceid)) 
               then  dlog:device($deviceid) 
               else if (exists($MAC)) 
                    then dlog:device-at-MAC($MAC)
                    else ()
let $log := collection($dlog:logs)/log[@id=$device/id]
let $valid := exists($log) and $device/active
let $login := xmldb:login("/db/apps/logger","treeman","fagus")

return
   if (not($appid = $dlog:appid))
   then <response>request: {$request} : invalid appid  </response>   
   else if ($test-mode or not ($valid))
   then 
     let $log := collection($dlog:logs)/log[@id="config"]
     let $params := request:get-parameter-names()
     let $record := element record {
                          element ts {current-dateTime()},
                          for $param in $params
                          return element {$param} {request:get-parameter($param,())}
                         }
     let  $insert := update insert $record into $log
     return <response>Test logged</response>

   else if ($valid) 
   then 
      let $params := request:get-parameter-names()[not(starts-with(.,"_"))]
      let $record := element record {
                          element ts {current-dateTime()},
                          for $param in $params
                          return element {$param} {request:get-parameter($param,())}
                         }
      let $record-extended :=
                 element record {
                     $record/*,
                     for $field in $device/fields/field[tag]
                     return element {$field/id} {$record/*[name(.) = $field/tag]/string()},
                     for $field in $device/fields/field[compute]
                     let $compute := $field/compute
                     return 
                        let $call := concat("local:",$compute/method,"($compute,$record)")
                        let $val := util:eval($call) 
                        return element {$field/id} {$val}
                  }   
      let  $insert := update insert $record-extended into $log
      return <response>Report Logged</response>
   else 
      <response>request: {$request} : invalid appid ,device id  or MAC address   </response>
