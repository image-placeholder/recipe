---
layout: none
permalink: /sw.js
---
{% assign base_url = site.baseurl | default: "" %}

/**
 * JFA PWA Toolkit
 * https://github.com/jfadev/jfa-pwa-toolkit
 * license that can be found in the LICENSE file.
 *
 * @author Jordi Fernandes Alves <jfadev@gmail.com>
 * @version 0.1
 */

try{
const PWA_ROOT = '{{base_url}}/assets/js/pwa';

// Import configs
importScripts(PWA_ROOT + '/config.js');

// Import Main Service Worker
importScripts(PWA_ROOT + '/sw.js');
}catch(err){
console.log(err.message)
}
