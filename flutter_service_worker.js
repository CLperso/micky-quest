'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"index.html": "069e1398874b5da09ace9139c5f93a52",
"/": "069e1398874b5da09ace9139c5f93a52",
"flutter_bootstrap.js": "99195d3b6b5ba3091d16e91092aa0150",
"canvaskit/skwasm.worker.js": "89990e8c92bcb123999aa81f7e203b1c",
"canvaskit/chromium/canvaskit.js": "b7ba6d908089f706772b2007c37e6da4",
"canvaskit/chromium/canvaskit.wasm": "ea5ab288728f7200f398f60089048b48",
"canvaskit/chromium/canvaskit.js.symbols": "e115ddcfad5f5b98a90e389433606502",
"canvaskit/canvaskit.js": "26eef3024dbc64886b7f48e1b6fb05cf",
"canvaskit/skwasm.wasm": "828c26a0b1cc8eb1adacbdd0c5e8bcfa",
"canvaskit/canvaskit.wasm": "e7602c687313cfac5f495c5eac2fb324",
"canvaskit/canvaskit.js.symbols": "efc2cd87d1ff6c586b7d4c7083063a40",
"canvaskit/skwasm.js": "ac0f73826b925320a1e9b0d3fd7da61c",
"canvaskit/skwasm.js.symbols": "96263e00e3c9bd9cd878ead867c04f3c",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"assets/FontManifest.json": "3e0ddfdf12b573c15bba8155a26e2a1f",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/fonts/MaterialIcons-Regular.otf": "3c5d20c54291bd34efeb97837018dbb2",
"assets/NOTICES": "5ea616ecf52ae63042dba236b22a88e0",
"assets/assets/fonts/Nunito_700Bold.ttf": "c133c0b8cd169e7798d0cd239477cf32",
"assets/assets/fonts/CormorantGaramond_500Medium_Italic.ttf": "00fba85f30cf1c8ce55b2655eafd9289",
"assets/assets/fonts/CormorantGaramond_600SemiBold.ttf": "a772acca0082468aeed7caffa29bd04c",
"assets/assets/fonts/DancingScript_700Bold.ttf": "1803686a822e2b10ecd6909227cb8d25",
"assets/assets/fonts/Nunito_800ExtraBold.ttf": "2b1bb82750274fc2d1043bf3891cb531",
"assets/assets/fonts/Nunito_600SemiBold.ttf": "b1364260246b29fd9393a1a071f3af61",
"assets/assets/fonts/CormorantGaramond_500Medium.ttf": "a658532edc2b8919aa61752708c4e7cf",
"assets/assets/fonts/CormorantGaramond_600SemiBold_Italic.ttf": "ef275f3122ce4574dadd5b7d04b5a41f",
"assets/assets/fonts/PatrickHand_400Regular.ttf": "0b94e62171b862ddb28135554050f315",
"assets/assets/fonts/Nunito_500Medium.ttf": "04058d9f3583d30ece037e060c5b9721",
"assets/assets/fonts/DancingScript_600SemiBold.ttf": "3d52bed05c9e88e6b9605ddcf6db06ac",
"assets/assets/fonts/Nunito_900Black.ttf": "3ffae19d12dc67269f5cdd8d7a0aaeaf",
"assets/assets/micky/m09.jpg": "300c6704bd52bde9d43ff009768bf281",
"assets/assets/micky/m01.jpg": "0b1159d444964a42f036859a81c5a5c2",
"assets/assets/micky/m03.jpg": "0c44bbe76f020e80a70a1c1afac455e3",
"assets/assets/micky/m23.jpg": "3d7f69739660156ddd6fbaeb99c62aa7",
"assets/assets/micky/m07.jpg": "cb29ee298ca98db7a7cc87e2a034176b",
"assets/assets/micky/m31.jpg": "727d1607e460e8ec2775e6e1da774eb0",
"assets/assets/micky/m34.jpg": "65a7113a715b6252f95fce9f7f3767c3",
"assets/assets/micky/m37.jpg": "398d6152f4be329b7bee4a22e3a6052a",
"assets/assets/micky/m05.jpg": "4e9fc9a9e0b7a5cc9f8ef8149205fb22",
"assets/assets/micky/m11.jpg": "d81f10c5cd0e368e85f09b4a869dbccc",
"assets/assets/micky/m29.jpg": "3f0d7549402a02b957ee6c9d6f45a59d",
"assets/assets/micky/m26.jpg": "473aea24eb07d8e3bdfc082cf8ef5e30",
"assets/assets/micky/m12.jpg": "13e410a784ea1947b7f390165c2f0af9",
"assets/assets/micky/m28.jpg": "7bda5a733e45a2fc58a0dc2b76db5a72",
"assets/assets/micky/m24.jpg": "2919f5b36b88f8f2c2b836f382ddf0af",
"assets/assets/micky/m15.jpg": "11361cebeb3c91e7a9d711e44d6b460e",
"assets/assets/micky/m08.jpg": "0d00494be05671a9039e4a80e32866aa",
"assets/assets/micky/m18.jpg": "cafb3386ad5944c35f9de197c1cdece1",
"assets/assets/micky/m10.jpg": "8ea6c76e98fdfd202a4900d756d0b99b",
"assets/assets/micky/m30.jpg": "434b84faefa9d1f823fe79590b808c68",
"assets/assets/micky/m20.jpg": "b3d8ff201b2469b6342925aa83cbec34",
"assets/assets/micky/m38.jpg": "149a92764304a0360e990ed7134f2c8d",
"assets/assets/micky/m13.jpg": "ad0c507504a1aa4ee30490c255b64a59",
"assets/assets/micky/m19.jpg": "96bc71b1f682a73229bafdc0f3b722dd",
"assets/assets/micky/m33.jpg": "2002a38f1e7ae1c5eb237bf782ad88ae",
"assets/assets/micky/m36.jpg": "bb843a7b73c9bd6e6cd2a42db89310e1",
"assets/assets/micky/m04.jpg": "0d9482f6509677f82ff56b0e5ad1196d",
"assets/assets/micky/m21.jpg": "e047bf57f040fc53ab847634a4abb2e8",
"assets/assets/micky/m22.jpg": "f009108907dda951ad49f8096691dd85",
"assets/assets/micky/m35.jpg": "02e12ef72e038325a944f7adffd0b09d",
"assets/assets/micky/m27.jpg": "29afc6a7984a7cfab2fd4822bf08c9ed",
"assets/assets/micky/m06.jpg": "d1e7760459fa720468d62d30622b40c2",
"assets/assets/micky/m02.jpg": "da7c7db02a4aef7f536f9a616081d7d0",
"assets/assets/micky/m32.jpg": "32417627380357016af87bf663ec5498",
"assets/assets/micky/m16.jpg": "38090fcd3ee8cc307915dfa83d45c29c",
"assets/assets/micky/m17.jpg": "3d1e8199425d8bdcfb832f565a932527",
"assets/assets/micky/m25.jpg": "100468a4f6a8ee6ac3f5f72bf2994389",
"assets/assets/micky/m14.jpg": "9ca086170410ebbf9c1d2de9e6feec19",
"assets/AssetManifest.bin": "c5e15788ec181f5432752e28e753903c",
"assets/AssetManifest.json": "82314f810f4877f7df76ef3adce183d9",
"assets/AssetManifest.bin.json": "8ffd4406507eaea6d59028980b7da588",
"flutter.js": "4b2350e14c6650ba82871f60906437ea",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"manifest.json": "3a96c0c9912da215636680df5a91c85b",
"version.json": "deb0efe66900b5522fb7839aca3c84b1",
"main.dart.js": "ba320486adc5389fdfc3a90de01762f8"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
