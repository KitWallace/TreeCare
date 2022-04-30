module namespace lgn ="http://kitwallace.co.uk/lib/lgn";
import module namespace config ="http://kitwallace.co.uk/lib/config" at "lgn-config.xqm";

(: ----------------- login --------------------------- :)

declare function lgn:login-panel() {
   let $user-name := lgn:user()
   let $user := $config:users/user[username=$user-name]
   return 
      <div>
          {if ($user)
          then <div>
          <div>{$user-name} Logged in |  <a href="{$config:root}?mode=logout">Logout</a> </div>
              </div>
          else <div><div><a href="{$config:root}?mode=login">Login</a></div> <div><a href="{$config:root}?mode=register-form">Register</a></div> </div>
          }
     </div>
};

declare function lgn:dispatch($mode) {
   element div {
    if ($mode="login-panel")
    then lgn:login-panel()
    else if ($mode="login-form") 
    then lgn:login-form()
    else if ($mode="login")
    then lgn:login()
    else if ($mode="logout")
    then lgn:logout()
    else if ($mode="register-form")
    then lgn:register-form()
    else if ($mode="register")
    then lgn:register()
    else if ($mode="confirm")
    then lgn:confirm()
    else if ($mode="reset-password")
    then lgn:forgotten()
    else if ($mode="reset-form")
    then lgn:reset-form()
    else if ($mode="reset")
    then lgn:reset()
    else lgn:login-form()
    }
};

declare function lgn:login-form() {
 <div>
   <div>
     <h3>Login</h3>
     <form action="{$config:root}" method="post">
     email address&#160;<input name="email" size="30"/> &#160;Password &#160; 
     <input type="password" name="password"/>&#160;
     <input type="submit" name="mode" value="login"/> <br/>  <br/> 
   
   </form>
   </div>
   <div>
     <h3>Forgotten password</h3>  
     <form  action="{$config:root}" method="post"> 
      email address&#160;<input name="email" size="30"/> &#160;
      <input type="submit" name="mode" value="reset-password"/>
      </form>   
    </div>
   <div>
    <br/><h3>Not registered</h3>
    <div>If you are not already a user, then <a href="{$config:root}?mode=register-form">Register</a>. </div>
   </div>
 </div>
};

declare function lgn:login() {
  let $email := request:get-parameter("email",())
  let $password := request:get-parameter("password",())
  let $user := $config:users/user[email=$email]
  return
    if (exists($user) and exists($user/date-joined) and util:hash($password,"MD5") = $user/password)
    then 
       let $session := session:set-attribute("user",$user/username)
       let $max := session:set-max-inactive-interval(-1)
       return  response:redirect-to(xs:anyURI($config:root))
    else 
       <div>Login details are incorrect. Please try to <a href="{$config:root}?mode=login-form">login again </a> or reset your password.</div>
};

declare function lgn:user() {
   if (session:exists()) then session:get-attribute("user") else ()
};

declare function lgn:admin-user() {
     if (session:exists()) 
     then let $username := session:get-attribute("user")
          return exists($config:users/user[username=$username]/admin)
     else false()
};

declare function lgn:super-user() {
     if (session:exists()) 
     then let $username := session:get-attribute("user")
          return exists($config:users/user[username=$username]/super-user)
     else false()
};

declare function lgn:logout() {
  let $user := lgn:user()
  let $invalidate := session:clear() 
  return
    response:redirect-to(xs:anyURI($config:root)) 
};

(: ----------------- user registration ---------------------- :)

declare function lgn:register-form() {
 <div>
    <h3>Register new administrator</h3>
      <form action="?" method="post">
        <table>
        <tr><th>Email address</th><td> <input name="email" size="30"/></td></tr>
        <tr><th>Username</th><td> <input name="username" size="30"/></td></tr>
        <tr><th>Password</th><td> <input type="password" name="password"/></td></tr>
        <tr><th>Repeat Password</th><td> <input type="password" name="password2"/> </td></tr>      
        <tr><th>Secret</th><td> <input type="text" name="secret"/>   </td></tr>    
        <tr><th/><td><input type="submit" name="mode" value="register"/></td></tr>
        </table>
     </form>
  </div>
};

declare function lgn:register () {
let $email := request:get-parameter("email",())
let $username := request:get-parameter("username",())
let $password := request:get-parameter("password",())
let $password2 := request:get-parameter("password2",())
let $secret := request:get-parameter("secret",())
let $existing-user := $config:users/user[email=$email]
return
if (empty($existing-user) and $username ne "" and  $password ne "" and $password = $password2  and contains ($email,"@") and $secret = $config:secret)
then  
   let $create := lgn:create-member($email,$username,$password)  
   return <div>{$create}</div>  
else 
  if ($existing-user)
  then <div>This email address is already registered</div>
  else <div>There is a problem with your registration. Please check that the two passwords are the same, the email address is a valid email address and that the secret phrase has been correctly entered.</div>
};

declare function lgn:create-member($email, $username, $password) {
  let $rid := util:uuid()
  let $user := 
<user>
   <username>{string($username)}</username>
   <email>{string($email)}</email>
   <password>{util:hash($password,"MD5")}</password>
    <rid>{$rid}</rid>
</user>
  let $login := xmldb:login($config:base,"treeman","fagus")

  return
     if (exists($config:users/user[username=$username]))
     then <div>membername already exists</div>
     else 
         let $update := update insert $user into $config:users
         let $confirm := lgn:send-confirm($user)
         return
           if ($confirm)
           then <div>
                An email has been sent to {$email}.  Please click on the link in the email to confirm your registration. Note that you may have to look in your junk folder.
               </div>
           else 
              <div>Whoops - something went wrong with the email address {$email}. Please try again. </div> 
};


declare function lgn:send-confirm($user)  {
let $link := concat($config:root,"?mode=confirm&amp;rid=",$user/rid)
let $email := $user/email/string()
let $message := 
  <mail>
   <from>kit.wallace@gmail.com</from>
   <to>{$email}</to>
   <subject>{$config:site-name} registration</subject>
   <message>
     <xhtml><div>
            
             If you have registered for the {$config:site-name} site, please confirm your registration by clicking on the link below:
             
             <a href="{$link}">{$link}</a>   
          
            </div>
     </xhtml>
   </message>
  </mail>
 
let $mail := mail:send-email($message,(),())
return
    $mail
};

declare function lgn:confirm() {
    let $rid := request:get-parameter("rid",())
    let $user := $config:users/user[rid=$rid]
    let $login := xmldb:login($config:base,"treeman","fagus")

    return 
       if ($user)
       then let $update := update insert element date-joined {current-dateTime()} into $user
            return <div>You have now completed registration. You can now <a href="{$config:root}?mode=login-form">login.</a></div>
       else <div>No such user</div>
};

declare function lgn:forgotten() {
    let $email := request:get-parameter("email",())
    let $user := $config:users/user[email=$email]
    return 
       if ($email = "")
       then <div>Please provide your email address</div>
       else if (empty($user))
       then <div>No such user</div>
       else 
        let $login := xmldb:login($config:base,"treeman","fagus")
        let $rid := util:uuid()
        let $update := if ($user/rid) then update replace $user/rid with element rid {$rid} else update insert element rid {$rid} into $user
        let $link := concat($config:root,"?mode=reset-form&amp;rid=",$user/rid)
        let $message := 
  <mail>
   <from>kit.wallace@gmail.com</from>
   <to>{$email}</to>
   <subject>{$config:site-name} password reset</subject>
   <message>
     <xhtml><div>
            
             If you have requested a password reset, click on the link below:
             
             <a href="{$link}">{$link}</a>   
          
            </div>
     </xhtml>
   </message>
  </mail>
 
let $mail := mail:send-email($message,(),())
return
     if ($mail)
     then <div>
                An email has been sent to {$email}.  Please click on the link in the email to reset your password. Note that you may have to look in your junk folder.
          </div>
     else 
          <div>Whoops - something went wrong with the email address {$email}. Please try again. </div> 
};

declare function lgn:reset-form() {
   let $rid := request:get-parameter("rid",())
   let $user := $config:users/user[rid=$rid]
   return 
       if ($user)
       then 
          <div><form action="?" method="post">
          <input type="hidden" name="email" value="{$user/email}"/>
          New Password <input type="password" name="password"/><br/>
          Repeat Password <input type="password" name="password2"/> <br/>
          <input type="submit" name="mode" value="reset"/>
         </form>
         </div>
      else <div>no such user</div>
};

declare function lgn:reset() {
let $email := request:get-parameter("email",())
let $password := request:get-parameter("password",())
let $password2 := request:get-parameter("password2",())
let $user := $config:users/user[email=$email]
return
if (exists($user) and  $password ne "" and $password = $password2 )
then  
   let $login := xmldb:login($config:base,"treeman","fagus")
   let $update  := update replace $user/password with element password {util:hash($password,"MD5")}  
   return <div>Password changed - now login</div>
   
else 
  <div>There is a problem with your password reset - please try again</div>
};


