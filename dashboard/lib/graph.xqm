module namespace graph = "http://kitwallace.me/lib/graph";
import module namespace dlog = "http://kitwallace.me/lib/dlog" at "dlog.xqm";

(:
  work to do
  + detect when the fields are the same and just use one y axis
  +  allow colour to be defined for each graph esp if the same field
  +  merge events
  + show events  -  move all code to graph
  + units on y-axis
  ? second y-axis lines  - need the number of intervals to be the same
  + integrate with dashboard
    select time range
    axis as dates not offset
   
:)

declare function graph:data-values($deviceid,$field) {
   let $log := dlog:log($deviceid)
   let $data := 
              for $record in $log/record
              let $val := $record/*[name(.)=$field]
              where exists($val) 
              order by $record/ts ascending
              return element record {
                                     attribute ts {$record/ts/string()},
                                     attribute field {$field},
                                     element data {string($val)}
                      }
    return $data
};

declare function graph:data-in-range($deviceid,$fieldid, $start as xs:dateTime ,$end as xs:dateTime) {
   let $log := dlog:log($deviceid)
   let $data := 
              for $record in $log/record
              let $val := $record/*[name(.)=$fieldid]
              where exists($val) and $record/ts >= $start and $record/ts <= $end
 (:             order by $record/ts ascending  :)
              return element record {
                                     attribute ts {$record/ts/string()},
                                     attribute field {$fieldid},
                                     element data {string($val)}
                      }
    return $data
};

declare function graph:x-axis($start as xs:dateTime,$end as xs:dateTime,$fontsize,$width,$height) {

(: origin at (0,height) :)

   let $time-range :=  $end - $start
   let $time-range-seconds := round ($time-range div xs:dayTimeDuration('PT1S'))
   let $time-range-minutes := round ($time-range div xs:dayTimeDuration('PT1M'))
   let $time-range-hours :=  round ($time-range div xs:dayTimeDuration('PT1H'))
   let $time-range-days := round ($time-range-hours div 24)
   let $xunits := if ($time-range-seconds < 200) then "seconds"
                  else if ($time-range-minutes < 240) then "minutes" 
                  else if ($time-range-hours <48) then "hours" 
                  else "days"
                  
   let $xinc := if ($xunits="seconds") then if ($time-range-seconds <= 10) then 1 else if ($time-range-seconds <= 60) then 10 else 30
                else if ($xunits="minutes") then if ($time-range-minutes <= 10) then 1 else if ($time-range-minutes <= 60) then 10 else 30
                else if ($xunits="hours") then if ($time-range-hours <= 10) then 1 else if ($time-range-hours <= 24) then 3 else 6
                else if ($xunits="days") then if ($time-range-days <= 10) then 1 else if ($time-range-days <= 20) then 2 else 5
                else 1
   let $xinc-unit-seconds := if($xunits = "minutes") then 60 else if ($xunits = "hours") then 60 * 60 else if ($xunits="days") then 60*60*24
       else 1
   let $xinc-seconds := $xinc * $xinc-unit-seconds
   let $xscale := $width div  $time-range-seconds
   let $xsteps := xs:integer(floor($time-range-seconds div ($xinc-seconds )))
   
   let $offset := $fontsize 
   return
     <result>
       <xscale>{$xscale}</xscale>
       <xsteps>{$xsteps}</xsteps>
       <g>
        {  for $i in 0 to $xsteps 
           let $j := $xsteps - $i
           let $x := round-half-to-even($width -  $j * $xinc-seconds *  $xscale,2)
           return
            (<polyline fill="none" style="stroke-dasharray:1 5" stroke="#0074d9" stroke-width="1" points="{$x},{$height}  {$x},0"/>,
             <text font-size="{$fontsize}pt" x="{$x - $offset}" y="{$height+$fontsize}">{round($j* $xinc)}</text>
            )
         }
         <text font-size="{$fontsize}pt" x="{$width div 2}" y="{$height+$fontsize*2.5}">age&#10;({$xunits})</text> 
       </g>
    </result>
};

declare function graph:y-axis($miny,$maxy,$yinc,$ydecimals,$yunit,$fontsize,$axis-x-inset,$width,$height) {
   let $base := $miny  
   let $yrange := $maxy - $miny
   let $yscale := $height div $yrange
   let $ysteps := xs:integer($yrange div $yinc)
   return
   <result>
      <yscale>{$yscale}</yscale>
      <g>
        {for $i in 0 to $ysteps 
         let $y := round($height -  ($i * $yinc)* $yscale)
         return
            <g>
               <polyline fill="none" style="stroke-dasharray:2 3" stroke="#0074d9" stroke-width="1" points="0,{$y}  {$width},{$y}"/>
               <text font-size="{$fontsize}pt" x="{$axis-x-inset}" y="{$y - 2}">{round-half-to-even($base + $i * $yinc,$ydecimals)}</text>              
            </g>
         }       
      </g>
   </result>
};

declare function graph:data-line ($data, $start as xs:dateTime,$end as xs:dateTime,$xscale,$yscale,$ymin,$fontsize,$height,$width,$stroke-color,$stroke-width) {
     let $points:=  string-join(
                     (for $d in $data
                      let $t := (xs:dateTime($d/@ts) - $start)  div xs:dayTimeDuration('PT1S')
                      return concat(
                               round-half-to-even($t * $xscale,2),", ",
                               round-half-to-even($height - ($d - $ymin) * $yscale,2),
                               " ")
                     )
                    ,",")  
     return    
       <g>
          <polyline fill="none" stroke="{$stroke-color}" stroke-width="{$stroke-width}" points="{$points}"/>
       </g>
};
declare function graph:events($device, $field, $start as xs:dateTime ,$end as xs:dateTime ) {
   for $event in $dlog:events/event
   where $event/deviceid=$device/id and (empty($event/field) or $event/field = $field/id)
                               and $event/ts >=$start and $event/ts <= $end
   return $event
};

declare function graph:list-events($events) {
   for $event at $i in $events
   let $char := codepoints-to-string(64+$i) 
   return <div><b>{$char}</b>&#160;{$event/description/string()} ({$event/username/string()})</div>
};
     
   
declare function graph:distinct-events($events) {
    for $ts in distinct-values($events/ts)
    order by $ts
    return $events[ts=$ts]
};

declare function graph:show-events($events,$start,$xscale,$fontsize,$height,$width) {
      for $event at $i in $events
      let $char := codepoints-to-string(64+$i)
      let $t := (xs:dateTime($event/ts) - $start) div xs:dayTimeDuration('PT1S')
      let $x := round-half-to-even($t * $xscale -5,2)
      return
            <text color="red" font-size="{$fontsize}pt" font-weight="bold" x="{$x}" y="{$height + 4 * $fontsize}"> {$char}</text>
};

declare function graph:show-graph($device,$field,$start,$end,$axis-x-inset,$xscale,$stroke-color,$fontsize,$width,$height,$show-yaxis) {
     let $ymin := $field/min
     let $ymax := $field/max
     let $yinc := $field/interval
     let $yunit := $field/unit
     let $decimals := ($field/decimals, 0)[1]
     let $yaxis :=  graph:y-axis($ymin,$ymax,$yinc,$decimals,$yunit,$fontsize,$axis-x-inset,$width,$height)
     let $data := graph:data-in-range($device/id,$field/id,$start,$end) 
     let $yscale := $yaxis/yscale
     let $stroke-width := 2
     return
         <g>
               {if($show-yaxis) then $yaxis/g else ()}
               {graph:data-line($data,$start,$end,$xscale,$yscale,$ymin,$fontsize,$height,$width,$stroke-color,$stroke-width)}
        </g>
};

declare function graph:single-field-graph($device, $field, $start as xs:dateTime,$end as xs:dateTime) {
         let $height :=300
         let $width := 800
         let $margin := 50
         let $origin := (2*$margin, $margin) 
        
         let $full-width := $width + 2 * $margin
         let $full-height := $height + 2 *$margin
         
        
         let $fontsize := 12
         let $stroke-width := 2
         let $stroke-color := $field/colour
 
         let $xaxis := graph:x-axis($start,$end,$fontsize,$width,$height)
         let $xscale := $xaxis/xscale
         let $events := graph:distinct-events(graph:events($device,$field,$start,$end))
         return
         <div>
            <h3>{$field/title/string()} ({$field/unit/string()}) 
            from {xsl:format-dateTime($start,"DD MMM - HH:mm")}  to  {xsl:format-dateTime($end,"DD MMM - HH:mm")}</h3>
 
            <br/>
            <svg class="cartesian" width ="{$full-width}" height="{$full-height}">
             <g transform="translate({$origin[1]} {$origin[2]})">
                {$xaxis/g}           
                {graph:show-graph($device,$field,$start,$end,-2*$fontsize,$xscale,$stroke-color,$fontsize,$width,$height,true())}  
                {graph:show-events($events,$start,$xscale,$fontsize,$height,$width)}
             </g>
           </svg>   
           {graph:list-events($events)}  
         </div>
};
declare function graph:dual-field-graph($device1, $field1, $device2, $field2, $colour2,$start as xs:dateTime,$end as xs:dateTime) {
         let $height :=300
         let $width := 800
         let $margin := 50
         let $origin := ($margin, $margin) 
        
         let $full-width := $width + 4 * $margin
         let $full-height := $height + 2 *$margin
     
         let $fontsize := 12
 
         let $xaxis := graph:x-axis($start,$end,$fontsize,$width,$height)
         let $xscale := $xaxis/xscale
         let $show-yaxis-2 := $field1 != $field2      
         let $events := graph:distinct-events((graph:events($device1,$field1,$start,$end),graph:events($device2,$field2,$start,$end)))
 
         return
         <div>
           <h3>{$device1/name/string()} : {$field1/title/string()}  ({$field1/unit/string()}) <span style="color:{$field1/colour}"> _____ </span> and 
            {if ($device1 != $device2)
             then 
              <span><a  target="_blank" class="external" href="?id={$device2/id}&amp;mode=graph">{$device2/name/string()}</a>:</span> 
             else ()
            }
           {$field2/title/string()}({$field2/unit/string()}) <span style="color:{$colour2}"> _____ </span> 
             from {xsl:format-dateTime($start,"DD MMM - HH:mm")}  to  {xsl:format-dateTime($end,"DD MMM - HH:mm")}</h3>
           <br/>
           <svg width ="{$full-width}" height="{$full-height}" class="chart">
             <g transform="translate({$origin[1]} {$origin[2]})">
                {$xaxis/g}
                {graph:show-graph($device1,$field1,$start,$end,-2*$fontsize,$xscale,$field1/colour,$fontsize,$width,$height,true())}
                {graph:show-graph($device2,$field2,$start,$end,$width+$margin,$xscale,$colour2,$fontsize,$width,$height,$show-yaxis-2 )}
                {graph:show-events($events,$start,$xscale,$fontsize,$height,$width)}
             </g>
           </svg>
            {graph:list-events($events)}  

         </div>
};
