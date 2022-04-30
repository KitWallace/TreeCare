xquery version "3.0";

import module namespace dlog ="http://kitwallace.me/lib/dlog" at "lib/dlog.xqm";
import module namespace tp = "http://kitwallace.co.uk/lib/tp" at "/db/apps/trees/lib/tp.xqm";
import module namespace lgn ="http://kitwallace.co.uk/lib/lgn" at "lib/lgn.xqm";
import module namespace graph = "http://kitwallace.me/lib/graph" at "lib/graph.xqm";

let $mode := request:get-parameter("mode","index")
let $deviceid := request:get-parameter("deviceid",())
let $device := dlog:device($deviceid)
let $fieldid := request:get-parameter("fieldid",())
let $field := dlog:field($fieldid)
let $login := xmldb:login("/db/apps/logger","admin","perdika")
return
   if ($mode = "CSV"  and  exists($device))
   then 
        let $fields := $device/fields/field         
        let $serialize := util:declare-option("exist:serialize","method=text media-type=text/plain")
        let $header := response:set-header('content-disposition', concat("attachment; filename=",$device/id,".csv") )
        let $log := dlog:log($device/id)
        return
        string-join((
          string-join(("Date/time","Unix timestamp",for $field in $fields let $field := dlog:field($field/id) return $field/title),","),
          for $record in $log/record
          order by $record/ts descending
          return
            string-join(($record/ts,
                dlog:dateTime-to-timestamp($record/ts),
                for $field in $fields
                return $record/*[name(.) = $field/id]
                ),",")
           
        ),"&#10;")
    else if ($mode="download-device-configuration" and exists($device))  
    then let $serialize := util:declare-option("exist:serialize","method=xml media-type=text/xml")
         let $header := response:set-header('content-disposition', concat("attachment; filename=",$device/id,".xml") )
         return $device 
         
    else if ($mode="download-field-configuration" and exists($field))  
    then let $serialize := util:declare-option("exist:serialize","method=xml media-type=text/xml")
         let $header := response:set-header('content-disposition', concat("attachment; filename=",$field/id,".xml") )
         return $field
   
    else 
        let $serialize := util:declare-option("exist:serialize","method=xhtml media-type=text/html")
        return 
          <html>
          <head>
                 <title>Sensor Dashboard</title>
                 <meta name="viewport" content="width=device-width, initial-scale=1"/>
                    <link rel="stylesheet" type="text/css"
            href="https://fonts.googleapis.com/css?family=Merriweather%20Sans"/>
    <link rel="stylesheet" type="text/css"
            href="https://fonts.googleapis.com/css?family=Gentium%20Book%20Basic"/>
    <link rel="stylesheet" type="text/css" href="assets/base.css" media="screen" ></link>
 
          </head>
          <body>
          {
   if ($mode="index")
   then 
     <div>
        <h2><a href="?mode=index">Sensor dashboard</a> &#160;>&#160; <a href="?mode=device">Devices</a> &#160;|&#160; <a href="?mode=field">Fields</a> &#160;|&#160; <a href="?mode=about">About</a> | 
           {if (lgn:user()) 
            then <span>{lgn:user()} &#160; > <a href="?mode=logout">Logout</a></span>  
            else <a href="?mode=login-form">Admin Login</a>
            }
            
            {if (lgn:super-user()) then 
             <span> &#160; | <a href="?mode=admin">Super Admin</a> </span>
            else ()}
        </h2>
        
        <table>
        <thead>
           <tr><th>Device</th><th>Name</th><th>Location</th><th>Earliest</th><th>Latest</th><th>updated mins</th><th># records</th><th>Status</th></tr>
        </thead>
        <tbody>

             {for $device in dlog:devices()[active]
              let $log := dlog:log($device/id)  
              let $treeid := $device/treeid
              let $tree := tp:get-tree-by-id($treeid)
              let $sitecode := ($device/sitecode,$tree/sitecode)[1]
              let $site := tp:get-site-by-sitecode($sitecode)

              let $count := count($log/*)
              let $first := $log/record[1]
              let $last := $log/record[$count]
              let $last-time := xs:dateTime($last/ts)
              let $minutes-since-last-update := floor((current-dateTime() - $last-time) div xs:dayTimeDuration("PT1M"))
              let $lost := $minutes-since-last-update > 2 * $device/refresh
              order by $device/id
               return
                <tr>
                <th><a href="?deviceid={$device/id}&amp;mode=graph">{$device/id}</a></th>
                <td>{$device/name/string()}</td>
                <td>{$device/location/string()}</td>
                <td>{xsl:format-dateTime($first/ts,"DD MMM - HH:mm")}</td>
                <td>{xsl:format-dateTime($last/ts,"DD MMM - HH:mm")}</td>
                <td class="n">{$minutes-since-last-update}</td>
                <td class="n">{$count}</td> 
                {if ($device/active)
          then
          if ($lost) 
                 then <td><span style="background-color:red">&#160;&#160;&#160;</span> Sensor not reporting</td> 
                 else if (empty($last)) then  <td><span style="background-color:red">&#160;&#160;&#160;</span> No records</td> 
                 else <td><span style="text-align:center;background-color:green">&#160;&#160;&#160;</span> Logging</td>
          else 
            <td><span style="text-align:center;background-color:grey">&#160;&#160;&#160;</span> Inactive</td>
         }
              </tr>
             }
             </tbody>
             </table>
             <hr/>
             <h3>Support services</h3>
             <div><a target="_blank" class="external" href="view-test-log.xq">View Sensor test log</a>
             </div>
         </div>
 else if ($mode="device" and empty($device))
 then 
     <div>
        <h2><a href="?mode=index">Sensor dashboard</a> &#160;>&#160; Devices </h2>
        <table>
        <thead>
           <tr><th>Device</th><th>Name</th><th>MAC</th><th>Location</th><th>Earliest</th><th>Latest</th><th>updated mins</th><th># records</th><th>Status</th></tr>
        </thead>
        <tbody>

             {for $device in dlog:devices()
              let $log := dlog:log($device/id)  
              let $treeid := $device/treeid
              let $tree := tp:get-tree-by-id($treeid)
              let $sitecode := ($device/sitecode,$tree/sitecode)[1]
              let $site := tp:get-site-by-sitecode($sitecode)
              let $count := count($log/record)
              let $first := $log/record[1]
              let $last := $log/record[$count]
              let $last-time := xs:dateTime($last/ts)
              let $minutes-since-last-update := floor((current-dateTime() - $last-time) div xs:dayTimeDuration("PT1M"))
              let $lost := $minutes-since-last-update > 2 * $device/refresh
              order by $device/id
              return
                <tr>               
                <th><a href="?deviceid={$device/id}&amp;mode=graph">{$device/id}</a></th>
                <td>{$device/name/string()}</td>
                <td>{$device/MAC/string()}</td>
                <td>{$device/location/string()}</td>
                <td>{xsl:format-dateTime($first/ts,"DD MMM - HH:mm")}</td>
                <td>{xsl:format-dateTime($last/ts,"DD MMM - HH:mm")}</td>
                <td class="n">{$minutes-since-last-update}</td>
                <td class="n">{$count}</td>
                {if ($device/active)
          then
          if ($lost) 
                 then <td><span style="background-color:red">&#160;&#160;&#160;</span> Sensor not reporting</td> 
                 else if (empty($last)) then  <td><span style="background-color:red">&#160;&#160;&#160;</span> No records</td> 
                 else <td><span style="text-align:center;background-color:green">&#160;&#160;&#160;</span> Logging</td>
          else 
            <td><span style="text-align:center;background-color:grey">&#160;&#160;&#160;</span> Inactive</td>
         }
              </tr>
             }
             </tbody>
             </table>
         </div>
 else if ($mode = "field" and empty ($field))
 then    <div>
         <h2><a href="?mode=index">Sensor dashboard</a> &#160;>&#160; Fields</h2>
          <table>
          <tr><th>Id</th><th>Title</th><th>Units</th><th>Min</th><th>Max</th><th>Interval</th></tr>
          {for $field in dlog:fields()
           order by $field/id
           return
             <tr>
             <td><a href="?mode=config&amp;fieldid={$field/id}">{$field/id/string()}</a></td>
             <td>{$field/title/string()}</td> 
             <td>{$field/unit/string()}</td> 
             <td>{if ($field/computed) then "yes" else ()}  </td>
             <td>{$field/min/string()}</td> 
             <td>{$field/max/string()}</td> 
             <td>{$field/interval/string()}</td> 
             </tr>
           }
          </table>
         </div>
 else if ($mode="config" and exists($field))
 then 
         <div>
         <h2><a href="?mode=index">Sensor dashboard</a> &#160;>&#160; <a href="?mode=field">Fields</a> &#160;>&#160; {$field/id/string()} </h2>
         <h3>XML configuration</h3>
            <pre>{serialize($field,$dlog:xmlser)}</pre>
         <h3>Devices </h3>
         <ul>{for $device in dlog:devices()
              where $device/fields/field/id = $field/id
              return
              <li><a href="?mode=config&amp;deviceid={$device/id}">{$device/id/string()}</a></li>
              }
         </ul>
          {if (lgn:user()) then
            <div>
                <h3>Download Configuration  </h3>
                <div><a href="?fieldid={$field/id}&amp;mode=download-field-configuration">Download </a> XML configuration from server </div>
                  
                <h3>Upload edited XML configuration</h3> 
                     <form  enctype="multipart/form-data" action="?" method="post">
                       <input type="hidden" name="fieldid" value="{$field/id}"/>
                       <input type="file" name="xml" /><br/>
                       <div>Update existing device configuration <input type="submit" name="mode" value="update-field-configuration"/> </div>
                       <div>Create new device configuration <input type="submit" name="mode" value="add-field-configuration"/></div>
                    </form>
                </div>
           else ()
           }
       </div>
 else if ($mode="config" and exists($device))
 then   
         <div>
         <h2><a href="?mode=index">Sensor dashboard</a> &#160;>&#160; Device {$device/id/string()} </h2>
         <h3>XML definition</h3>
            <pre>{serialize($device,$dlog:xmlser)}</pre>
         {if (lgn:user()) then
            <div> 
              <h3>Download Configuration </h3>
                <div><a href="?deviceid={$device/id}&amp;mode=download-device-configuration">Download </a> XML configuration from server </div>
             <h3>Upload edited XML configuration</h3> 
                   <form  enctype="multipart/form-data" action="?" method="post">
                     <input type="hidden" name="deviceid" value="{$device/id}"/>
                     <input type="file" name="xml" /><br/>
                     <div>Update existing device configuration <input type="submit" name="mode" value="update-device-configuration"/> </div>
                     <div>Create new device configuration <input type="submit" name="mode" value="add-device-configuration"/></div>
                    </form>
                </div>
           else ()
           }        
       </div>
   else if ($mode="update-device-configuration")  
         then let $xml :=util:parse(util:binary-to-string(request:get-uploaded-file-data('xml')))
              let $deviceid := $xml/device/id/string()
              let $device := dlog:device($deviceid)
              return 
                    if (empty($deviceid))
                    then <div>XML does not contain an id</div>
                    else if (exists($device))
                    then let $update := update replace $device with $xml
                         return
                           <div>Device {$deviceid} configuration updated </div>
                    else
                           <div>Device {$deviceid} does not exist or XML missing or invalid</div>
  else if ($mode="add-device-configuration")
           then let $xml :=util:parse(util:binary-to-string(request:get-uploaded-file-data('xml')))
                let $deviceid := $xml/device/id
                let $device := dlog:device($deviceid)
                return 
                    if (empty($deviceid))
                    then <div>XML does not contain an id</div>
                    else 
                    if (exists($device))
                    then 
                           <div>Device {$deviceid} already exists </div>
                    else let $add := update insert $xml into $dlog:devices
                         let $log := xmldb:store($dlog:logs,concat($deviceid,".xml"), <log id="{$deviceid}"></log>)
                         return
                           <div>Device {$deviceid} configuration added and log created </div>
  
  else if ($mode="update-field-configuration")  
         then let $xml :=util:parse(util:binary-to-string(request:get-uploaded-file-data('xml')))
              let $fieldid := $xml/field/id
              let $field := dlog:field($fieldid)
              return 
                    if (empty($fieldid))
                    then <div>XML does not contain a field id</div>
                    else if (exists($field))
                    then let $update := update replace $field with $xml
                         return
                           <div>Field {$fieldid} configuration updated </div>
                    else
                           <div>Field {$fieldid} does not exist or XML missing or invalid</div>
                           
   else if ($mode="add-field-configuration")
           then let $xml :=util:parse(util:binary-to-string(request:get-uploaded-file-data('xml')))
                let $fieldid := $xml/field/id/string()
                let $field := dlog:field($fieldid)
                return 
                    if (empty($fieldid))
                    then <div>XML does not contain a fieldid</div>
                    else 
                    if (exists($field))
                    then 
                           <div>Field {$fieldid} already exists </div>
                    else let $add := update insert $xml into $dlog:fields
                         return
                           <div>Field {$fieldid} configuration added  </div>
  
      
 else if ($mode="graph" and exists($device) and exists($field))
 then 
         let $device-field := $device/fields/field[id=$field/id]
         let $log := dlog:log($deviceid) 
         let $rstart := request:get-parameter("start-date",())
         let $rend := request:get-parameter("end-date",())       
         let $start := if ($rstart != "") then concat($rstart,"T00:00:00")  else $log/record[1]/ts
         let $end :=  if ($rend != "") then concat($rend,"T23:59:59")  else $log/record[last()]/ts       
         return
         <div>
                <h2><a href="?mode=index">Index</a> &#160;> <a href="?deviceid={$device/id}&amp;mode={$mode}">{$device/id/string()} : {$device/name/string()}</a> &#160; >  {$field/title/string()}</h2>
          {
           if ($device-field/compare)
           then let $device2 := dlog:device($device-field/compare/device)
                let $field2 := dlog:field($device-field/compare/field)
                let $colour2 := $device-field/compare/colour
                return
                 <div>
                   {graph:dual-field-graph($device,$field,$device2,$field2,$colour2,$start,$end)}  
                 </div>
            else 
                <div>
                   {graph:single-field-graph($device,$field,$start,$end)}
                 </div>
           }
         </div>
  else if ($mode=("graph","data","raw") and exists($device))
  then
        let $name := string(($device/name,$device/id)[1])
        let $treeid := $device/treeid
        let $tree := tp:get-tree-by-id($treeid)
        let $sitecode := ($device/sitecode,$tree/sitecode)[1]
        let $site := tp:get-site-by-sitecode($sitecode)
        let $log := dlog:log($device/id) 
        let $first := $log/record[1]
        let $last := $log/record[last()]
        let $last-time := xs:dateTime($last/ts)
        let $total-elapsed-time-hours :=  round-half-to-even((xs:dateTime($last/ts) - xs:dateTime($first/ts)) div xs:dayTimeDuration("PT1H"),1)
        let $total-elapsed-time-days :=  floor($total-elapsed-time-hours div 24)
        let $total-elapsed-time-day-hours := $total-elapsed-time-hours - $total-elapsed-time-days * 24
        let $minutes-since-last-update := round((current-dateTime() - $last-time) div xs:dayTimeDuration("PT1M"))
        let $lost := $minutes-since-last-update > 2 * $device/refresh
        let $log-length := count ($log/record) 
        let $daylog := subsequence($log/record, max(($log-length -  60,1)) , min((60,$log-length))) 
        let $total-run-time-minutes := round-half-to-even(sum($log/record/run_ms) div 1000 div 60,1)
             return
     <div>
        <h2><a href="?mode=index">Index</a> &#160;> {$device/id/string()} : {$device/name/string()}&#160;>&#160;<a href="?deviceid={$device/id}&amp;mode={$mode}">Refresh</a>
        &#160;| 
        {if ($mode != "graph") then <a href="?deviceid={$device/id}&amp;mode=graph">Show Graphs</a> else "Graphs" }&#160; |
        {if ($mode != "data") then <a href="?deviceid={$device/id}&amp;mode=data">Show Data</a> else "Data"}&#160; | 
        {if ($mode != "raw") then <a href="?deviceid={$device/id}&amp;mode=raw">Show Raw Data</a> else "Raw"}&#160; | 
        <a href="?deviceid={$device/id}&amp;mode=CSV">Export as CSV</a>
        </h2>
        <div>
        <table>
         <tr><th>Name</th><td>{$name}</td></tr>
         <tr><th>Device id</th><td>{$device/id/string()}</td></tr>
         {if ($device/MAC) then <tr><th>MAC</th><td>{$device/MAC/string()}</td></tr> else ()}
         {if ($tree) then <tr><th>Tree</th><td><a class="external" target="_blank" href="https://bristoltrees.space/Tree/tree/{$device/treeid}">{$device/treeid}</a></td></tr> else ()}
         {if ($site) then <tr><th>Location</th><td><a class="external" target="_blank" href="https://bristoltrees.space/Tree/sitecode/{$site/sitecode}">{$site/name[1]/string()}</a></td></tr> else ()}
         {if ($tree) then <tr><th>Species</th><td>{$tree/latin[1]/string()}</td></tr> else ()}
         {if ($device/location) then <tr><th>Location</th><td>{$device/location/string()}</td></tr> else ()}
         <tr><th>Update Frequency</th><td>{$device/refresh/string()} minutes</td></tr>
         {if ($device/board-version) then <tr><th>TTGO Board version</th><td>{$device/board-version/string()}</td></tr> else ()}
         <tr><th>Last updated</th><td>{xsl:format-dateTime($last/ts,"DD MMM - HH:mm")} </td></tr>
         <tr><th>Minutes since last update</th><td>{$minutes-since-last-update} minute{if ($minutes-since-last-update > 1) then "s" else ()}</td></tr>
         <tr><th>Total elapsed time</th><td>{$total-elapsed-time-days} Days&#160; {$total-elapsed-time-day-hours} Hours</td></tr>
         {if ($total-run-time-minutes = 0) then () else  <tr><th>Total run time </th><td>{$total-run-time-minutes} minutes</td></tr>}
         <tr><th>Number of records</th><td>{count($log/record)}</td></tr>
         
         {if ($device/alert-time) then <tr><th>Alert last sent</th> <td>{xsl:format-dateTime($device/alert-time,"DD MMM - HH:mm")}</td></tr> else ()}
         <tr><th>Status</th>
         {if ($device/active)
          then
          if ($lost) 
                 then <td><span style="background-color:red">&#160;&#160;&#160;</span> Sensor not reporting</td> 
                 else if (empty($last)) then  <td><span style="background-color:red">&#160;&#160;&#160;</span> No records</td> 
                 else <td><span style="background-color:green">&#160;&#160;&#160;</span> Active</td> 
          else 
            <td><span style="text-align:center;background-color:grey">&#160;&#160;&#160;</span> Inactive</td>
         }
         </tr>
         <tr><th>Custom graph</th><td><a href="?mode=graph-form&amp;deviceid={$device/id}">Construct</a></td></tr>
         {if ($device/link)
          then
           <tr><th>Further information</th><td>{
           for $link in $device/link
           return
           <span><a class="external" target="_blank" href="{$link/href}">{$link/title/string()}</a>&#160;</span>
           }
           </td>
           </tr>
           else ()
         }
         <tr><th>Configuration</th><td><a href="?deviceid={$device/id}&amp;mode=config">Configuration</a></td></tr>
         {if (lgn:user()) then <tr><th>Admin functions</th><td><a href="?deviceid={$device/id}&amp;mode=change">Admin</a></td></tr> else ()}
         
         </table>
         </div>
         {if (empty($last))
         then ()
         else 
         <div>
         <h3>Latest Data</h3>
          <table>{
          for $field in $device//field
          let $field-def := dlog:field($field/id)
          let $val := $last/*[name(.)=$field/id] 
          return <tr><th>{$field-def/title/string()} {if ($field-def/unit) then concat("(",$field-def/unit,")") else ()}</th><td class="n">{$val/string()}</td>
          {if ($field-def/bands)
           then let $band := dlog:get-band($val,$field-def/bands)
                return <td><span style="text-align:center;background-color:{$band/colour}">&#160;&#160;&#160;</span> {$band/text}</td>
           else ()
          }
           </tr>
          }
          </table>
          </div>
         }
        <div style="clear:both">

        {if (empty($last))
        then ()
        else 
        if ($mode="raw") 
        then
        let $fields := $last/(* except ts)/name(.)
        return     
         <div>
           <h3>Raw Readings</h3>
           <table>
             <thead>
               <tr><th>Timestamp</th>{for $f in $fields return <th>{for $fp in tokenize($f,"-") return <div style="padding-left:25px;text-align:right;">{$fp}</div>}</th>}</tr></thead>
             <tbody>
               {for $record in $log/record
                order by $record/ts descending
                return
                 <tr><td>{xsl:format-dateTime($record/ts,"HH:mm - DD MMM")}</td>         
                   {for $f in $fields return <td style="text-align:right">{$record/*[name(.) = $f]}</td>}
                 </tr>
               }      
             </tbody>
          </table>
        </div>
        else if ($mode="data")
        then 
      <div>
        {let $fields := $device/fields/field   
         return
        <table>
        <thead>
        <tr><th>Date/time</th>
                {for $field in $fields 
                 let $field-def := dlog:field($field/id)  
                 let $fp := tokenize($field-def/title,"\s+")
                 return 
                    <th>
                      { for $f in $fp return <div style="padding-left:25px;text-align:right;">{$f}</div>}                    
                      {if ($field-def/unit) then <div style="padding-left:25px;text-align:right;">{concat(" (",$field-def/unit,")")}</div> else ()}
                    </th>
                }
        </tr></thead>
        <tbody>
        {for $record in $log/record
         order by $record/ts descending
         return
            <tr>
               <td>{xsl:format-dateTime($record/ts,"DD MMM - HH:mm")}</td>
                {for $field in $fields
                 let $field-def := dlog:field($field/id)
                 let $field-val := $record/*[name(.)= $field/id]/string()
                 let $band-span := 
                    if ($field-def/bands)
                    then let $band := dlog:get-band($field-val,$field-def/bands)
                         return <span style="text-align:center;background-color:{$band/colour}">&#160;&#160;&#160;</span>
                    else ()
                return <td style="text-align:right">{$field-val}&#160;{$band-span}</td>
               }               
           </tr>
        }        
        </tbody>
        </table>
        }
      </div>
      else if ($mode="graph" and $log-length >3)
      then
       <div>
         {for $field in $device/fields/field[empty(nograph)]
          let $field-def := dlog:field($field/id)
          let $start := $first/ts
          let $end :=  $last/ts  
          
          return 
          
           if ($field/compare)
           then let $device2 := dlog:device($field/compare/device)
                let $field2 := dlog:field($field/compare/field)
                let $colour2 := $field/compare/colour
                return
                 <div>
                   {graph:dual-field-graph($device,$field-def,$device2,$field2,$colour2,$start,$end)}  
                 </div>
            else 
                <div>
                   {graph:single-field-graph($device,$field-def,$start,$end)}
                 </div>
         }
         </div>

       else ()
       }
       </div>
       </div>
    else if ($mode = "graph-form"  and exists($device))
    then              
         let $log := dlog:log($device/id) 
         return
         <div>
         <h2><a href="?">Index</a> &#160;>{$device/id/string()}: {$device/name/string()}&#160;>&#160;<a href="?deviceid={$device/id}&amp;mode={$mode}">Graphs</a> | Custom graph </h2>
         <form action="?">
            <input type="hidden" name="deviceid" value="{$device/id}"/>
            
           <table>
             <tr><th>Field</th><td>
                  <select name="fieldid">
                    {for $field in $device/fields/field
                     let $field-def := dlog:field($field/id)
                     return
                        element option { 
                             attribute value {$field/id} ,
                             if ($field/id = $fieldid)
                             then attribute selected {"selected"} 
                             else (),
                             $field-def/title/string()
                       }
                     }
                  </select>
             </td></tr>
             <tr><th>Start date</th><td><input type="text" name="start-date" value="{substring($log/record[1]/ts,1,10)}" size="15"/></td></tr>
             <tr><th>End date</th><td><input type="text" name="end-date" value="{substring($log/record[last()]/ts,1,10)}" size="15"/></td></tr>
           </table>
           <input type="submit" name="mode" value="graph"/>
         </form>
       
       </div>
    else if ($mode="about")
    then 
      <div>
         <h2><a href="?">Index</a> &#160;> About</h2>
         <h3>Background</h3>
             <div>This dashboard reports on data provided by various sensors, mainly the readings from experimental moisture and temperature sensors which are being placed in strategic locations in Bristol. There is more about this project in <a target="blank" class="external" href="https://kitwallace.tumblr.com/tagged/moisture">a series of blog posts</a>.
             </div>

         <h3>Resources</h3>
            <ul>
               <li><a target="_blank" class="external" href="https://0.rc.xiniu.com/g3/M00/8F/0D/CgAH6F-zL82Aeup2AAUkucb2Lsg882.jpg">LilyGo -T-Call pinout</a></li>
               <li><a target="_blank" class="external" href="https://github.com/KitWallace/TreeCare/blob/master/arduino/tree-sensor-v3.ino">Current Arduino source V3</a>  This is the version running in the two deployed devices.  Calibration values, GSM connection parameters, sleep interval and sometimes pin assignments vary by physical device</li>
               <li><a target="_blank" class="external" href="https://github.com/KitWallace/TreeCare/blob/master/arduino/calibrate-sensor-v2.ino">Calibration script</a> for calibration the moisture sensor and determining which temp sensor is which.</li>
               <li><a target="_blank" class="external" href="https://github.com/KitWallace/TreeCare/blob/master/BOM.ods">Bill of Materials</a> The initial BOM with links to most suppliers.</li>
               <li><a target="_blank" class="external" href="https://github.com/KitWallace/TreeCare/blob/master/arduino/configurationguide.odt">Configuration Guide</a> (in preparation)</li>
            </ul>
         <h3>Device configuration</h3>
         <div>Configuration data for devices is held in an XML file.  Admin users can download the configuration for a device or a field, edit it and upload it back to the server.  There is a more user-friendly editor for the Earthwatch devcices  </div>
         <div>
         For the full edit, since the file is XML, you need an XML-aware editor, both for ease of editing and to ensure that the XML is well-formed.
         Notepad++ is a useful tool but you will need to install the XML plugin which allows the XML to be check for well-formedness and supports XML-aware editing. 
         Schema valdation is also supported by this plugin and a schema for the configuration data will provided RSN.</div>
         <div>To create a new device, download a similar device configuration, edit the data and set the id for the new device, and then upload the configuration as a new device.  The device will be added and an empty log file created. </div>
         <div>Similarly,to create a new field, download a similar field configuration, edit the data and set the id for the new field, and then upload the configuration as a new field. </div>
       
         
         <h3>Sensor device to do for V6</h3>
            <ul>
               <li>No changes currently planned</li>
            </ul>
         <h3>Dashboard to do</h3>
            <ul>
              <li>Admin user ✓</li>
              <li>create/edit device configuration ✓ </li>
              <li>create/edit field configuration ✓</li>
              <li>device and field schemas and doocumentation </li>
              <li>Graph X axis as date/time or time offset (current)</li>
              <li>Select period for graphs  ✓, data</li>
              <li>Graph to compare two sequences from the same or different devices ✓</li>
              <li>Value banding for any field  ✓</li>
              <li>field units ✓</li>
              <li>Computed fields ✓</li>
              <li>Event editor ✓</li>
              <li>Viewing archived data</li>
              <li>Include schedule tasks from super-user ✓</li>
              <li>integrate weather data as a device ✓</li>
              <li>mark missing real data (testing..)</li>
           </ul>
         <div>Feedback to kit.wallace@gmail.com.</div>
      </div>
      else if ($mode="change" and exists ($device) and lgn:user())          
           then
           
               <div>
               <h2><a href="?">Index</a> &#160;><a href="?deviceid={$device/id}&amp;mode=graph">{$device/id/string()} : {$device/name/string()}</a> > Admin</h2>
                
               {if (lgn:admin-user())
                then
                <div>
                <h3>Admin functions</h3>
                
                <form action="?">
                <input type="hidden" name="deviceid" value="{$device/id}"/>

                {if ($device/active) 
                then <span><b>Logging</b>&#160;<input type="submit" name="mode" value="stop-logging"/></span>
                else <span><b>Logging</b>&#160;<input type="submit" name="mode" value="start-logging"/></span>
                }
 <!--              <br/><br/>
                 <b>Clear log </b>
               <br/><br/> 
               <b>Archive to </b>
               Date: <input type = "text" name="archive-to-date" value="{substring(string(current-date()),1,10)}" size="12"/>&#160;Time: 
               <input type = "text" name="archive-to-time" value="{substring(string(current-time()),1,5)}" size="8"/>
               
               <input type="submit"  name="mode" value="archive"/> 
               
                <input type="submit"  name="mode" value="clear"/> 
 -->
 
                </form>
                </div>
                else ()
                }
 
                <div><b>Add event</b>
                <div>An event may be an intervention such as watering or weeding around the tree, an observation of the state of the tree such as wilting, damaged or, heaven forfend, dead or an exceptional weather event.  In general routine weather data will be provided by a <a href="http://www.martynhicks.uk/weather/data.php" target="_blank" class="external"> nearby weather station.</a>
                </div>
                <form action="?">
                <input type="hidden" name="deviceid" value="{$device/id}"/>

                Date: <input type = "text" name="event-date" value="{substring(string(current-date()),1,10)}" size="12"/>&#160;Time: 
               <input type = "text" name="event-time" value="{substring(string(current-time()),1,5)}" size="8"/>&#160; Field 
               <select name="field">
                  <option >all</option>
                  {for $field in $device/fields/field
                   return <option>{$field/id}</option>
                  }
               </select><br/>
               
               Description: <input type="text" size="80" name="description"/><br/>
               
                <input type="submit"  name="mode" value="addevent"/> 
                </form>
                </div>
                {if ($device/software-version="V6.6")
                then 
                
               <div>
               <b>Edit configuration</b>
                 {let $moisture-air := $device//field[id="moisture-pc"]/compute/parameter[@id="air"]
                  let $moisture-water := $device//field[id="moisture-pc"]/compute/parameter[@id="water"]
                  let $air-temp-sensor := $device//field[id="air-temp-C"]/tag
                 
                  return
                 <form action="?">
                  <input type="hidden" name="deviceid" value="{$device/id}"/>
                  <table>
                  <tr><th>Name</th><td><input type="text" name="name" value="{$device/name}" size="20"/></td></tr>
                  <tr><th>Location</th><td><input type="text" name="location" value="{$device/location}" size="20"/></td></tr>
                  <tr><th>Alert email address</th><td><input type="text" name="device-alert-email" value="{$device/device-alert-email}" size="20"/></td></tr>
                  <tr><th>Moisture reading - air </th><td><input type="text" name="moisture-air" value="{$moisture-air}" size="5"/></td></tr>
                  <tr><th>Moisture reading - water </th><td><input type="text" name="moisture-water" value="{$moisture-water}" size="5"/></td></tr>
                  <tr><th>Air Temperature sensor</th><td><select size="2" name="air-temp-sensor">
                          {if ($air-temp-sensor = "temp-C-0") then <option selected="selected">temp-C-0</option> else <option>temp-C-0</option>}
                          {if ($air-temp-sensor = "temp-C-1") then <option selected="selected">temp-C-1</option> else <option>temp-C-1</option>}
                          </select>  
                  </td></tr>
                  <tr><td colspan="2"><input type="submit"  name="mode" value="update"/>  &#160; <input type="submit"  name="mode" value="cancel"/>  &#160; </td></tr>
                  </table>
                 
                 </form>
                 }
               </div>
               else ()
               }
              </div>
           else if ($mode="update" and exists($device) and lgn:user())
           then 
                let $air-temp-sensor := request:get-parameter("air-temp-sensor",())
                let $soil-temp-sensor := if ($air-temp-sensor = "temp-C-0") then "temp-C-1" else "temp-C-0"
                let $new-device := util:deep-copy ($device)
                let $new-device := 
                    element device {
                        $new-device/(* except (name, location, device-alert-email, fields)),
                        element name {request:get-parameter("name",())},
                        element location {request:get-parameter("location",())},
                        element device-alert-email{request:get-parameter("device-alert-email",())},
                        element fields  {
                            $new-device/fields/(* except (field[id=("moisture-pc","soil-temp-C","air-temp-C")])),
                            if ($new-device//field[id="moisture-pc"])
                            then element field {
                                    $new-device//field[id="moisture-pc"]/(* except compute),
                                    element compute {
                                        element method {"convert-moisture"},
                                        element parameter  { attribute id {"air"} , request:get-parameter("moisture-air",())},
                                        element parameter  { attribute id {"water"} , request:get-parameter("moisture-water",())}
                                    }
                                 }
                            else (),
                             if ($new-device//field[id="air-temp-C"])
                             then element field {
                                     $new-device//field[id="air-temp-C"]/(* except tag),
                                     element tag {$air-temp-sensor}}
                             else (),                         
                             if ($new-device//field[id="soil-temp-C"])
                             then element field {
                                     $new-device//field[id="soil-temp-C"]/(* except tag),
                                     element tag {$soil-temp-sensor}}
                             else ()
                        }            
                    }              
                 let $update := update replace $device with $new-device 
                 return 
                 
                 <div> {$device/id} updated </div>
                 
           else if ($mode=("archive","delete") and exists($device))
           then let $archive-to-date := request:get-parameter("archive-to-date",())
                let $archive-to-time := request:get-parameter("archive-to-time",())
                let $archive-to := concat($archive-to-date,"T",$archive-to-time,":59.999")
                let $archive-filename := concat($archive-to-date,"T",replace($archive-to-time,":","-"),".xml") 
                let $log := dlog:log($device/id) 
                let $logname := util:document-name($log)
                let $total-records := count($log/record)
                let $archive-records :=  $log/record [ts <= $archive-to ]
                let $keep-records :=   $log/record [ts > $archive-to ] 
                
                let $store-archive := 
                   if ($mode = "archive")
                   then xmldb:store($dlog:archive-path,concat($device/id,"-archive-",$archive-filename),
                     element log {attribute id {$device/id}, $archive-records})
                   else ()
                let $store-keep := xmldb:store($dlog:logs,$logname,
                     element log {attribute id {$device/id}, $keep-records})
                    
                return
                  <div>{$device/id/string()} Total Records : {$total-records},  Archived to : {$archive-to}, Records  archived : {count($archive-records)},Records kept : {count($keep-records)} in {$logname} </div>
           
           else if ($mode="clear")
           then <div>You are clearing the log for {$device/id/string()} - <form action="?">
                 <input type="hidden" name="deviceid" value="{$device/id}"/>
                 Yes really - <input type="submit" name="mode" value="Really Clear"/>&#160;
                 Sorry, ignore that <input type="submit" name="mode" value="change"/>
    
                 </form>
           
                </div>
           else if ($mode="Really Clear")
           then
               let $log := dlog:log($device/id) 
               let $total-records := count($log/record)
               let $store-clear :=  xmldb:store("/db/apps/logger/logs",concat($device/id,".xml"),
                     element log {attribute id {$device/id}, ()})
                return
                    <div>{$device/id/string()} log cleared</div> 
           else if ($mode="start-logging")
               then let $update := update insert element active {} into $device
                    return <div>Logging of {$device/id/string()} started.</div>
           else if ($mode="stop-logging")
               then let $update := update delete $device/active
                    return <div>Logging of {$device/id/string()} stopped.</div>
           else if ($mode="addevent")
           then  let $date := request:get-parameter("event-date",())
                 let $time := request:get-parameter("event-time",())
                 let $field := request:get-parameter("field",())
                 let $event := element event {
                                  element ts {concat($date,"T",$time,":00")},
                                  element deviceid {$device/id/string()},
                                  if ($field !="all") 
                                  then element field {$field}
                                  else (),
                                  element description {request:get-parameter("description",())},
                                  lgn:user()
                               }
                 let $add := update insert $event into $dlog:events
                 return <div>{$event} Event added  {$add}</div>
            else if ($mode="admin" and empty ($device) and lgn:super-user())
            then let $action := request:get-parameter("action","index")
                 let $login :=xmldb:login("/db/apps/login","admin","perdika")
                 return
                 if ($action="index")
                 then dlog:admin-page()
                 else if ($action="cancel-alerts")
                 then dlog:cancel-alerts()
                 else if ($action="schedule-alerts")
                 then dlog:schedule-alerts()
                 else if ($action="cancel-weather")
                 then dlog:cancel-weather()
                 else if ($action="schedule-weather")
                 then dlog:schedule-weather()
                 else ()
            else lgn:dispatch($mode)  
          }
          </body>
          </html>
   
