import module namespace vol = "http://kitwallace.co.uk/lib/vol" at "vol.xqm";
import module namespace tp = "http://kitwallace.co.uk/lib/tp" at "lib/tp.xqm";
import module namespace wfn= "http://kitwallace.me/wfn" at "/db/lib/wfn.xqm";
import module namespace url = "http://kitwallace.me/url" at "/db/lib/url.xqm";

declare option exist:serialize "method=xhtml media-type=text/html omit-xml-declaration=yes indent=yes 
        doctype-public=-//W3C//DTD&#160;XHTML&#160;1.0&#160;Transitional//EN
        doctype-system=http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd";
        
let $context := url:get-context()
let $sig := $context/_signature
return
<html lang="en">
  <head>
  <title>BTC- Bristol Tree Carers</title>
    <meta charset="UTF-8"/>
    
    <link rel="stylesheet" type="text/css"
            href="https://fonts.googleapis.com/css?family=Alegreya%20SC"/>
    <link rel="stylesheet" type="text/css"
            href="https://fonts.googleapis.com/css?family=Open%20Sans"/>
     <meta name="viewport" content="width=device-width, initial-scale=1"/>
    <link href="./assets/trecup.png" rel="icon" sizes="128x128" />
    <link rel="shortcut icon" type="image/png" href="/trees/tree-care/assets/trecup.png"/>
    <link rel="stylesheet" type="text/css" href="/trees/tree-care/assets/vol-base-os.css" media="screen" ></link>
    <link rel="stylesheet" type="text/css" href="/trees/tree-care/assets/vol-pr.css" media="print" ></link>
    <script  src="/trees/javascript/sorttable.js"></script> 
    {if ($sig="map")
     then let $trees := tp:get-tree-by-collection("Downs Tree Trail")
     return
         (  
            <script src="https://ajax.googleapis.com/ajax/libs/jquery/1.7.1/jquery.min.js"></script>, 
            <script src="https://maps.googleapis.com/maps/api/js?key={$tp:googlekey}"></script>,
            <script type="text/javascript"> var draggable = 'false'; </script>,
            <script  src="map.js"></script> ,
            vol:centre($tp:centre[1],$tp:centre[2]),
            vol:tree-markers($trees)
         )
         else ()
     }
  </head>
<body>
{ if ($sig="QR/*")
  then 
   
   <div width="200px" align="center" >
   <h1><a href="{$vol:root}"><img src="/trees/tree-care/assets/trecup.png" width="50px"/></a><br/>Bristol Tree Carers</h1>
     <br/>
     <h3>Tree ID {$context/QR}</h3>
    <canvas id="qrcodeCanvas"/>
    <script  src="assets/qrcode-ds.js"></script> 

    <script>
            (function(){{
               var qr= new QRious ({{
                 element:document.getElementById('qrcodeCanvas'),
                 value: '{concat("https://treecarers.org.uk/Care/tree/",$context/QR)}',
                 size:200
                 }});
              }})();
              
     </script>
     
     </div>
 else
<div>
<h2><a href="{$vol:root}"><img src="/trees/tree-care/assets/trecup.png" width="50px"/></a>&#160;Bristol Tree Carers&#160;
  <span style="font-size:smaller" class="nopr nav">   
   <a href="{$vol:root}caring">WHY?</a>
   <a href="{$vol:root}tree">TREES</a> 
   <a href="{$vol:root}map">MAP</a>  
   <a href="{$vol:root}carer">CARERS</a>
   </span>
   </h2>
   <hr width="50%" align="left"/>
{if ($sig="tree/*" or $sig="tree/*/carer/*")
 then 
   let $id := $context/tree/string()
   let $carer := $context/carer/string()
   let $tree := tp:get-tree-by-id($id)
   return
   if ($tree)
   then 
  <div>
     <h3>The Tree &#160; <a target="_blank" class="external" href="https://bristoltrees.space/Tree/tree/{$id}">{$id}</a>
    &#160;  <a href="{$vol:root}QR/{$id}">QR code</a>
     </h3>
        
     {vol:photo(tp:get-tree-photos($tree/id)) }
     <div id="text">
              <h4>{$tree/common/string()}&#160;[{$tree/latin/string()}] </h4>
              <h4>Located in {tp:get-site-by-sitecode($tree/sitecode[1])/name[1]/string()} </h4>
              {if ($tree/date-planted) then 
              <h4>Planted {if ($tree/date-planted castable as xs:date) then xsl:format-date($tree/date-planted,"DD MMM YYYY") else $tree/date-planted/string()}</h4>
              else ()
              }
              <div>{tp:to-html($tree/text)}</div>
             
      
           {let $records :=  $vol:worklog/record[id=$id]
            let $total-time := sum($records/time)
            return
            if ($records)
            then 
       <div>
         <h3>Tree Care</h3>
         {for $record in $records
          order by  $record/date
          return
            <div class="entry">
              {xsl:format-date($record/date,"DD MMM")} : 
              <a href="{$vol:root}carer/{$record/nickname}">{$record/nickname/string()}</a>&#160;
              {$record/work/string()} {if ($record/time > 0) then concat(" for ",$record/time," minutes") else ()}.
              {$record/comment/string()}

            </div>
          }
          <p>The tree has had {sum($records/time)} minutes of care.</p>
         </div>
    else ()
    }
     <div style="font-size:16pt; font-weight:bold; color:#0D0D16;">Record care or observations 
     <a href="{$vol:root}tree/{$id}{if ($carer) then concat("/carer/",$carer) else ()}/add">
     here</a></div>
  
    </div>

  </div>
else 
   <div id="text">
         <div>{if (exists($id)) then "This does not match a tree" else ()}</div>
         <form action="?" >
                  <div>What tree did you work on?  <input type="text" name="id" value="{$id}" size="10"/> 
                  
                 <input type="submit" name="mode" value="find"/>
                 </div>
         </form>
   </div>
else if ($sig=("tree/*/add","tree/*/carer/*/add") )
then 
  let $id := $context/tree/string()
   let $carer := $context/carer/string()
   let $tree := tp:get-tree-by-id($id)
   return
   <div>
     <h3>Recording the work {if ($carer) then <span>by <a href="{$vol:root}carer/{$carer}">{$carer}</a></span> else () }
        on tree {$id}</h3>
 
      <form action="{$vol:root}tree/{$id}/save">
      {if ($context/carer)
      then <input type="hidden" name="carer" value="{$carer}"/>
      else
      <div>
    
      <div class="tooltip">Your nickname 
       <span class="tooltiptext">If this is your first record of work, choose a 'unique' name so that you can track the work you do</span>
     </div> <br/>
        <input type="text" name="carer" value="{$carer}" size="20" /><br/>
     </div>
     }
     <div class="tooltip">How long did you work in minutes?
           <span class="tooltiptext">In 15 minute intervals is fine</span> 
     </div>
     <br/>
     <input type="text" name="time" size="20"/><br/>
      <div class="tooltip">What did you do?
      <span class="tooltiptext">Tell us about the work you did on this tree: watering, weeding, mending the wire cage..</span>
      </div><br/>
     <textarea name="work" cols="60" rows="3"/><br/>
      <div class="tooltip">What needs to be done next?
     <span class="tooltiptext">Such as more watering, replacing the tree because its dead, mending the support or the cage</span></div><br/>
     <textarea name="comment" cols="50" rows="3"/><br/>
     <input type="submit" name="mode" value="save" color="red"/><input type="submit" name="mode" value="cancel"/>
   
     </form>
   </div>   
else if ($sig="tree/*/save")
then 
       let $id:= $context/tree/string()
       let $carer:= $context/carer/string()
       let $time := request:get-parameter("time",())
       let $time := if ($time = "") then 0 else $time
       let $work := request:get-parameter("work",())
       let $comment := request:get-parameter("comment",())

       let $record :=
          element record {
            element date {current-date()},
            element nickname {$carer},
            element id {$id},
            element time {$time},
            element work {$work},
            element comment {$comment}
          }
      let $update := update insert $record into $vol:worklog
      return 
         <div id-="text">
           Well done {$carer}, your efforts have been logged. <br/>
           <a href="{$vol:root}tree/{$id}/carer/{$carer}">Do you want to record more work on that tree</a> or look at <a href="{$vol:root}carer/{$carer}">your record of work?</a>
          
         </div>
else if ($sig ="carer/*")
then 
  let $records := $vol:worklog/record[nickname=$context/carer]
  let $total-time := sum($records/time)
  return
   <div>
    <h3>carer {$context/carer}</h3>
    <div>Work so far : {$total-time} minutes </div>
    <table>
    <tr><th>Date</th><th>Tree</th><th>Minutes</th><th>Work done</th><th>Comment</th></tr>
    {for $record in $records
     order by  $record/date
     return
       <tr><td class="nb">{xsl:format-date($record/date,"DD MMM")}</td>
          <td><a href="{$vol:root}tree/{$record/id}/carer/{$context/carer}">{$record/id/string()}</a></td>
          <td>{$record/time/string()}</td>
          <td>{$record/work/string()}</td>
          <td>{$record/comment/string()}</td>
       
       </tr>
     }
    </table>
    <br/>
    <div class="nopr">
    Add work on a new tree <form action="?" style="display: inline;"><input type="hidden" name="nickname" value="{$context/carer}" /><input type="text" name="tree" value="{$context/tree}" size="10"/> <input type="submit" name="mode" value="find"/> </form>
    </div>
    </div>
else if ($sig ="tree")
then 
  let $ids:= distinct-values($vol:worklog/record/id)
  
  return 
  <div>
  <h3>Care of the Trees</h3>
    <table class="sortable">
    <tr><th>Tree</th><th>Minutes</th><th>carers</th></tr>
    {for $id in $ids
     let $records := $vol:worklog/record[id=$id]
     let $total-time := sum($records/time)
     let $nicks := distinct-values($records/nickname)
     order by $id
     return
       <tr>
          <td><a href="{$vol:root}tree/{$id}">{$id}</a></td>
          <td>{$total-time}</td>
          <td>{wfn:node-join(for $nickname in $nicks return <a href="{$vol:root}carer/{$nickname}">{$nickname}</a>,", "," and ")}</td>      
       </tr>
     }
    </table>
    
    </div>
 else if ($sig ="carer")
then 
  let $records := $vol:worklog/record
  let $carers := distinct-values($vol:worklog//nickname)
  return 
     <div>
     <h3>The carers</h3>
     <table class="sortable">
      <tr><th>carer</th><th>Minutes</th><th>Trees worked on</th></tr>
      {for $carer in $carers
       let $nick-records := $vol:worklog/record[nickname=$carer]
       let $total-time := sum($nick-records/time)
       let $ids := distinct-values($nick-records/id)
       order by $carer
       return
       <tr><th><a href="{$vol:root}carer/{$carer}">{$carer}</a></th><td>{$total-time}</td>
          <td>{wfn:node-join(for $id in $ids return <a href="{$vol:root}tree/{$id}">{$id}</a>,", "," and ")}</td></tr>
       }
     </table>
     </div>
else if ($sig="map")
then 
  <div>
      <div id="map_legend">
        <span style="font-weight:bold;font-size:14pt;">Trees needing care </span> <br/>
        Not visited <img src="/trees/assets/freetree.png"/><br/>
        # times visited <img src="/BSA/images/lightblue3.png"/> <br/>
      </div>
      <div id="map_canvas"></div>
  </div>
else if ($sig="todo")
then 
<div>To do: 
<ul>
 <li>nickname registration to ensure uniqueness and? offer to gather email address;</li>
 <li>rewards?</li>
 <li>validation checks;</li>
 <li>enter date of work?</li>
 <li>prettify web design - getting better I think</li>
 <li><s> mobile phone behaviour</s></li>
 <li>carer added photo - would need moderation process </li>

 <li><s>tree collection page - as a map</s></li>
 <li>print bulk QR labels </li>
 <li><s>split about into UFCF and tech pages - link from home page</s></li>
 <li><s>domain name</s> tentative</li>
 <li><s>Logo</s> needs touchup</li>
 <li>describe the need for care</li>
 <li>describe how to use the site</li>
 </ul>
</div>

else if ($sig="UTCF")
then 
<div>
   <h3>The Urban Tree Challenge Fund</h3>
   <div id="text">
   <div>
     The <a target="_blank" class="external" href="https://assets.publishing.service.gov.uk/government/uploads/system/uploads/attachment_data/file/803593/7767_FC__A5__Leaflet_Urban_Tree_Challenge_DR7_RL_HI_RES.pdf">Urban Tree Challenge Fund</a> (UTCF) has been developed in response to HM Treasury releasing £10 million in the 2018 Autumn Budget announcement for planting at least 20,000 large trees and 110,000 small trees in urban areas in England.

    The UTCF will support a number of objectives in Defra’s 25 Year Environment Plan and also contribute towards meeting Government’s manifesto commitment to plant one million urban trees by 2022.
   </div>
   <div>Bristol has secured ..  funding and plans to use this to plant trees on <a  target="_blank" class="external" href="https://bristoltrees.space/Tree/siteCategory/UTCF%20Planting%20site">10 woodland sites</a> and as well as 240 planting sites around Bristol.
   </div>

   </div>
      
   </div>
else if ($sig="website")
then 
  <div>
   <div id="text">
   <h3>The website</h3>
    <div>On this website, carers can record the work they do in tending the new planting: watering, fixing the supports, weeding and make a note of attention which the tree needs. So far, carers have contributed {round(sum($vol:worklog/record/time) div 60)} hours of care to these trees. 
   </div>
   </div>
  {vol:photos()} 
</div>
else if ($sig ="tech")
then 
<div>
  <div id="text">
   <h3>The technology</h3>
   <div> 
Developed with the open source <a  target="_blank" class="external" href="http://exist-db.org">eXist db</a>. 
 Code and issues are on <a target="_blank" class="external" href="https://github.com/KitWallace/TreeCare">Github</a>


   </div>

<div>This website is designed to be eco-friendly. 
We use an independent UK-based VPS host <a target="_blank" class="external" href="http://bitfolk.com">BitFolk</a>; 
the page design is simple so that pages load fast and less energy is used; 
pages are printable with no wasted ink;
the design is light; dark colours use more energy to display.

</div>
<div script="font-size:smaller" class="nopr">
<a href="{$vol:root}todo">Work to do</a>
</div>
</div>
  {vol:photos()}
</div>
else if ($sig="caring") 
then 
  <div>
    <h3>Caring for trees</h3>
    <div>Newly planted trees need  ....</div>
    
    <h3>Sites</h3>
    <ul>
    <li> <a href="https://www.cambridge.gov.uk/cambridge-canopy-project">Cambridge Canopy Project</a>&#160; <a href="https://twitter.com/CamCanopyProj">Twitter</a></li>
    <li><a href="https://twitter.com/CambridgeTrees_">Cambridge MA </a></li>
    </ul>
  </div>
else 
   <div>
     <div id="bigphoto"><img src="/trees/assets/PeaceGrove_3b.jpg" width="600px;" alt="Peace Grove"/></div>
     <div id="sidebar">      
        <h3>Caring for Trees</h3>
        <div style="font-size:16pt;">554 trees have been planted this winter and now they need YOUR care:<br/>
        <ol>
        <li class="big">Find a tree on the <a href="{$vol:root}map">map</a> <br/> or scan a QR code like <a href="{$vol:root}QR/30249">this one</a></li>
        <li class="big">Check out its needs</li>
        <li class="big">Help the tree</li>
        <li class="big">Tell us what you did</li>
        </ol>
        
        </div>
        <div style="font-size:16pt;"><span style="color:red">{round(sum($vol:worklog/record/time) div 60)} hours</span>of care<br/> contributed so far.
        </div>
      </div>
        <hr/>
        <div>About the <a href="{$vol:root}website">Website</a>| About the <a href="{$vol:root}tech">Technology</a> 
        </div>
        <hr/>
<div>A <a  target="_blank" class="external" href="https://bristoltrees.space">bristoltrees.space</a> production for <a  target="_blank" class="external" href="https://bristoltreeforum.org/">Bristol Tree Forum</a>
and <a  target="_blank" class="external" href="https://www.bristol.gov.uk/museums-parks-sports-culture/parks-and-open-spaces">Bristol City Council</a>
</div>
   </div>
          
}
</div>
}
</body>

</html>
