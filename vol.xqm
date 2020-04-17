module namespace vol = "http://kitwallace.co.uk/lib/vol";
import module namespace tp = "http://kitwallace.co.uk/lib/tp" at "../lib/tp.xqm";

declare variable $vol:root := "/Care/";
declare variable $vol:worklog :=  doc("/db/apps/trees/tree-care/worklog.xml")/work;

declare function vol:centre($lat,$long) {
<script type="text/javascript">
   var centre =  new google.maps.LatLng($lat,$long);
</script>
};
declare function vol:tree-markers($strees) {
<script type="text/javascript">
var markers = [
   { string-join(
       for $tree at $i in $strees
       let $visits := $vol:worklog/record[id=$tree/id]
       let $visit-text := if ($visits) 
                      then if (count($visits)>1) 
                           then concat("Visited ",count($visits)," times.")
                           else "Visited once"
                      else "Not yet visited"
       let $visitor := if ($visits)
                       then  concat("Last visited by ",$visits[last()]/nickname)
                       else ()
       let $name := replace($tree/common[1],"'","\\'")
       let $latin := replace($tree/latin[1],"'","\\'")
       let $title :=  concat($latin," : ",$name," : ",$tree/id) 
       let $icon :=  if ($visits) 
                     then 
                          element icon {concat("/BSA/images/lightblue",count($visits),".png")}
                     else element icon {"/trees/assets/freetree.png"}
       let $description :=  util:serialize(
         <div>
              <h3><em>{$latin}</em></h3>
              <div>{$name}<br/>
                   {if ($tree/state != "Tree") then $tree/state/string() else ()}&#160;  <br/>
                   
                   {$visit-text}<br/>
                   {$visitor}<br/>
                   <b><a href="{$vol:root}tree/{$tree/id}">{$tree/id/string()}</a></b><br/>
              </div>
         </div>,
          "method=xhtml media-type=text/html indent=no") 
       return
          concat("['",$title,"',",
                  $tree/latitude/string(),",",$tree/longitude/string(),
                  ",'",$description,"','",$icon,"']")
       ,",&#10;")
     }
     ];
</script>
};

declare function vol:photos() {
       let $ids := distinct-values($vol:worklog/record/id)
       let $photos := tp:get-tree-photos($ids)
       return 
         vol:photo($photos)
};

declare function vol:photo($photos) {
     if ($photos)
     then   let $n := ceiling(util:random() * count($photos))
            let $photo := $photos[$n]
            let $date := if ($photo/date castable as xs:date) 
                   then xs:date($photo/date) 
                   else xs:date(substring($photo/dateStored,1,10))
            return
            <div id="photo">
              <a href="/trees/photos/{$photo/photoid}"> <img src="/trees/photos/{$photo/photoid}" height="400" alt="{$photo/caption}">
                           {if ($photo/rotate-cw) then attribute class {"rotatecw"} else if ($photo/rotate-acw) then attribute class {"rotateacw"} else()}</img> </a>
              <br/>
              <h3><a href="{$vol:root}tree/{$photo/treeid}">{$photo/treeid/string()}</a>&#160; {$photo/caption/string()}</h3>
              <div>photo by {if (starts-with($photo/photographer,"http")) 
                       then <a href="{$photo/photographer}">{if (contains($photo/photographer,"twitter")) 
                                                             then concat("@",substring-after($photo/photographer,"twitter.com/") )
                                                             else  $photo/photographer/string()}
                            </a>
                       else $photo/photographer/string()
                       }
              on {if (exists($date)) then xsl:format-date($date,"DD MMM YYYY")else ()}
              
               </div>
           </div>
     else ()
 };