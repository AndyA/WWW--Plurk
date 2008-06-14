<?php

$nick_name = 'johndoe';
$password = 'secret!';

require 'RLPlurkAPI.php';

$plurk = new RLPlurkAPI();
$plurk->login($nick_name, $password);

// these are my friends/fans
print_r($plurk->friends);


//echo "\n\n------ getAlerts ------\n";
//echo "These are the friend requests you have:\n";
//$alerts = $plurk->getAlerts();
//print_r($alerts);

// Uncomment to accept all friend requests from the alert queue.
//$plurk->befriend($alerts, true);


// Uncomment to deny all friend requests from the alert queue.
//$plurk->befriend($alerts, false);


/*
 * Get my plurks.
 */
//echo "\n\n------ getUnreadPlurks ------\n";
//print_r($plurk->getUnreadPlurks(true));

//echo "\n\n------ getPlurks ------\n";
//print_r($plurk->getPlurks($plurk->uid));

// get plurks with responses from a certain time.
//print_r($plurk->getPlurks($plurk->uid, '2008-02-01T01:10:00', '2008-02-01T01:00:00'));


//echo "\n\n------ addPlurk ------\n";
//$plurk->addPlurk('en', 'is', 'tired (:');

//echo "\n\n------ respondToPlurk ------\n";
//echo $plurk->respondToPlurk(RLPlurkAPI::permalinkToPlurkID(___permalink_url___), 'en', 'says', 'test from RLPlurkAPI');


//echo "\n\n------ getResponses ------\n";
//print_r($plurk->getResponses(___plurk_id___));
//print_r($plurk->getResponses(RLPlurkAPI::permalinkToPlurkID(___permalink_url___))); // same thing


//$response = $plurk->respondToPlurk(RLPlurkAPI::permalinkToPlurkID(___permalink_url___), 'en', 'says', 'reply test from RLPlurkAPI');
//var_dump($response);


//$permalink = "http://www.plurk.com/p/ajd4";
//echo "Plurk id of $permalink: " . RLPlurkAPI::permalinkToPlurkID($permalink) . "\n\n";


?>
