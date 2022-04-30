import module namespace dlog ="http://kitwallace.me/lib/dlog" at "lib/dlog-2.xqm";
import module namespace csv = "http://kitwallace.me/csv" at "/db/lib/csv.xqm";

let $url := "https://www.martynhicks.uk/weather/wxsqlall2.php"
let $current-ymd := tokenize(current-date(),"-")
let $year := $current-ymd[1]
let $month := $current-ymd[2]
let $parameters := string-join((concat("formYear=",$year),concat("formMonth=",$month),"formPeriod=60","submit2=submit"),"&amp;")
let $header :=
      <headers>
         <header name="Content-Type"
                  value="application/x-www-form-urlencoded"/>
         <header name="Accept" value="text/html"/>
      </headers> 
let $doc := httpclient:post(xs:anyURI($url),$parameters,false(),$header)
let $doc-html := util:parse-html(util:binary-to-string($doc//httpclient:body))
let $csv-url := concat("https://www.martynhicks.uk/weather/", $doc-html//body/p/a[2]/@href)
let $raw-csv := httpclient:get(xs:anyURI($csv-url),false(),())//httpclient:body
let $csv := util:binary-to-string($raw-csv)
let $weather := csv:convert-to-xml($csv,"records","record",",",(),2) 
let $log := dlog:log("weather")
let $last-date := $log/record[last()]/ts
return 
if (empty($weather/record))
then  ()
else

       for $record in $weather/record
       let $ts := concat($record/DATE,"T",$record/TIME)
       where exists ($record/DATE) and xs:dateTime($ts) > $last-date
       return
         let $record := 
           element record {
             element ts {$ts},
             element air-temp-C {$record/TEMPC/string()},
             element humidity {$record/HUM/string()},
             element rainfall {$record/RATEmmhr/string()},
             element baro {$record/BAROmb/string()},
             $record/UV
          }
         return update insert $record into $log

 
