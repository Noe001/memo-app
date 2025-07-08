// Service Worker for MemoApp PWA
// Phase 5: Mobile Optimization

const CACHE_NAME = 'memoapp-v1.0.0';
const urlsToCache = [
  '/',
  '/memos',
  '/manifest.json',
  '/assets/application.css',
  '/assets/memo_app_shadcn.css',
  '/assets/mobile_optimization.css',
  '/assets/application.js',
  '/assets/memos_index.js',
  '/offline.html'
];

// Service Worker インストール
self.addEventListener('install', (event) => {
  console.log('Service Worker: Installing...');
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => {
        console.log('Service Worker: Caching files');
        return cache.addAll(urlsToCache);
      })
      .then(() => {
        console.log('Service Worker: Installation complete');
        return self.skipWaiting();
      })
  );
});

// Service Worker アクティベート
self.addEventListener('activate', (event) => {
  console.log('Service Worker: Activating...');
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          if (cacheName !== CACHE_NAME) {
            console.log('Service Worker: Deleting old cache:', cacheName);
            return caches.delete(cacheName);
          }
        })
      );
    })
    .then(() => {
      console.log('Service Worker: Activation complete');
      return self.clients.claim();
    })
  );
});

// フェッチイベント処理
self.addEventListener('fetch', (event) => {
  event.respondWith(
    caches.match(event.request)
      .then((response) => {
        // キャッシュがある場合はそれを返す
        if (response) {
          return response;
        }

        // キャッシュがない場合はネットワークからフェッチ
        return fetch(event.request)
          .then((response) => {
            // レスポンスが無効な場合はそのまま返す
            if (!response || response.status !== 200 || response.type !== 'basic') {
              return response;
            }

            // レスポンスをキャッシュに保存
            const responseToCache = response.clone();
            caches.open(CACHE_NAME)
              .then((cache) => {
                cache.put(event.request, responseToCache);
              });

            return response;
          })
          .catch(() => {
            // ネットワークエラーの場合はオフラインページを表示
            if (event.request.mode === 'navigate') {
              return caches.match('/offline.html');
            }
          });
      })
  );
});

// バックグラウンド同期
self.addEventListener('sync', (event) => {
  if (event.tag === 'memo-sync') {
    event.waitUntil(syncMemos());
  }
});

// プッシュ通知
self.addEventListener('push', (event) => {
  console.log('Service Worker: Push received');
  
  const options = {
    body: event.data ? event.data.text() : 'New memo activity',
    icon: '/apple-touch-icon.png',
    badge: '/badge-icon.png',
    vibrate: [200, 100, 200],
    data: {
      dateOfArrival: Date.now(),
      primaryKey: 1
    },
    actions: [
      {
        action: 'explore',
        title: 'Open MemoApp',
        icon: '/images/checkmark.png'
      },
      {
        action: 'close',
        title: 'Close notification',
        icon: '/images/xmark.png'
      }
    ]
  };

  event.waitUntil(
    self.registration.showNotification('MemoApp', options)
  );
});

// 通知クリック処理
self.addEventListener('notificationclick', (event) => {
  console.log('Service Worker: Notification clicked');
  
  event.notification.close();
  
  if (event.action === 'explore') {
    event.waitUntil(
      clients.openWindow('/memos')
    );
  }
});

// メモ同期関数
async function syncMemos() {
  try {
    const response = await fetch('/api/memos/sync', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        lastSync: localStorage.getItem('lastSync') || Date.now()
      })
    });
    
    if (response.ok) {
      localStorage.setItem('lastSync', Date.now().toString());
      console.log('Service Worker: Memo sync completed');
    }
  } catch (error) {
    console.error('Service Worker: Memo sync failed:', error);
  }
}

// オフライン状態の検出
self.addEventListener('online', () => {
  console.log('Service Worker: Back online');
  // オフラインで作成されたメモを同期
  syncMemos();
});

self.addEventListener('offline', () => {
  console.log('Service Worker: Going offline');
});

// インストールプロンプトの制御
self.addEventListener('beforeinstallprompt', (event) => {
  console.log('Service Worker: Before install prompt');
  event.preventDefault();
  // インストールプロンプトを保存
  self.deferredPrompt = event;
});

// アプリインストール後
self.addEventListener('appinstalled', (event) => {
  console.log('Service Worker: App installed');
  self.deferredPrompt = null;
});

// メッセージ処理
self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});

// 定期的なバックグラウンドタスク
self.addEventListener('periodicsync', (event) => {
  if (event.tag === 'memo-cleanup') {
    event.waitUntil(cleanupOldMemos());
  }
});

// 古いメモの清理
async function cleanupOldMemos() {
  try {
    const cache = await caches.open(CACHE_NAME);
    const keys = await cache.keys();
    
    const oldRequests = keys.filter(request => {
      const url = new URL(request.url);
      return url.pathname.includes('/memos/') && 
             Date.now() - parseInt(url.searchParams.get('timestamp') || '0') > 7 * 24 * 60 * 60 * 1000; // 7日以上古い
    });
    
    await Promise.all(oldRequests.map(request => cache.delete(request)));
    console.log('Service Worker: Old memos cleaned up');
  } catch (error) {
    console.error('Service Worker: Cleanup failed:', error);
  }
} 
