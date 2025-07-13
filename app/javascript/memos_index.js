function initializeMemoIndex() {
  const forms = document.querySelectorAll('.search_form');
  
  forms.forEach(form => {
    form.addEventListener('keydown', function(event) {
      if (event.key === 'Enter') {
        event.preventDefault();
        this.submit();
      }
    });
  });

  // タグフィルタリング機能
  let activeTag = null;
  const tagItems = document.querySelectorAll('.tag-item');
  const memoItems = document.querySelectorAll('.memo-item');

  tagItems.forEach(tagItem => {
    tagItem.addEventListener('click', function() {
      const tagName = this.dataset.tag;
      
      // 既にアクティブなタグがクリックされた場合、フィルターをクリア
      if (activeTag === tagName) {
        clearTagFilter();
        return;
      }

      // 新しいタグでフィルタリング
      setActiveTag(tagName);
      filterMemosByTag(tagName);
    });
  });

  function setActiveTag(tagName) {
    // 全てのタグからactiveクラスを削除
    tagItems.forEach(item => item.classList.remove('active'));
    
    // クリックされたタグにactiveクラスを追加
    const clickedTag = document.querySelector(`[data-tag="${tagName}"]`);
    if (clickedTag) {
      clickedTag.classList.add('active');
    }
    
    activeTag = tagName;
  }

  function clearTagFilter() {
    // 全てのタグからactiveクラスを削除
    tagItems.forEach(item => item.classList.remove('active'));
    
    // 全てのメモを表示
    memoItems.forEach(memo => {
      memo.style.display = 'block';
    });
    
    activeTag = null;
    updateEmptyState();
  }

  function filterMemosByTag(tagName) {
    let visibleCount = 0;
    
    memoItems.forEach(memo => {
      const memoTags = memo.querySelectorAll('.memo-tag');
      let hasTag = false;
      
      memoTags.forEach(tag => {
        if (tag.textContent.trim() === tagName) {
          hasTag = true;
        }
      });
      
      if (hasTag) {
        memo.style.display = 'block';
        visibleCount++;
      } else {
        memo.style.display = 'none';
      }
    });
    
    updateEmptyState(visibleCount === 0, tagName);
  }

  function updateEmptyState(isEmpty = false, tagName = null) {
    const memoList = document.querySelector('.memo-list');
    let emptyState = memoList.querySelector('.tag-filter-empty');
    
    if (isEmpty && tagName) {
      if (!emptyState) {
        emptyState = document.createElement('div');
        emptyState.className = 'tag-filter-empty empty-state';
        emptyState.innerHTML = `
          <div class="empty-icon">
            <i data-lucide="tag" style="width: 3rem; height: 3rem;"></i>
          </div>
          <h3>「${tagName}」タグのメモが見つかりません</h3>
          <p>このタグが付いたメモがありません。<br>他のタグを選択するか、新しいメモを作成してください。</p>
          <button class="btn btn-secondary" onclick="clearTagFilter()">フィルターをクリア</button>
        `;
        memoList.appendChild(emptyState);
        
        // Lucideアイコンを再初期化
        if (typeof lucide !== 'undefined') {
          lucide.createIcons();
        }
      } else {
        emptyState.querySelector('h3').textContent = `「${tagName}」タグのメモが見つかりません`;
      }
    } else if (emptyState) {
      emptyState.remove();
    }
  }

  // グローバル関数として定義（ボタンから呼び出すため）
  // Lucide アイコンを毎回描画し直す
  if (typeof lucide !== 'undefined') {
    lucide.createIcons();
  }

  window.clearTagFilter = clearTagFilter;
}


// 初期化を複数のイベントで実行 (Turbo/Traditional)
document.addEventListener('DOMContentLoaded', initializeMemoIndex);
document.addEventListener('turbolinks:load', initializeMemoIndex); // Legacy support
// Rails 7 / Turbo Drive
if (typeof Turbo !== 'undefined') {
  document.addEventListener('turbo:load', initializeMemoIndex);
}

// ドロップダウン外をクリックした時に閉じる
document.addEventListener('click', function(event) {
  const dropdown = document.querySelector('.export-dropdown');
  const button = document.querySelector('.export-dropdown-btn');
  
  if (dropdown && !dropdown.contains(event.target)) {
    dropdown.classList.remove('open');
  }
});

// ESCキーでドロップダウンを閉じる
document.addEventListener('keydown', function(event) {
  if (event.key === 'Escape') {
    const dropdown = document.querySelector('.export-dropdown');
    if (dropdown) {
      dropdown.classList.remove('open');
    }
  }
});
