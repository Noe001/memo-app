window.onload = function() {
  let element = document.getElementById('circle_1');
  let radiusX = 100; // X軸半径
  let radiusY = 50;  // Y軸半径
  let centerX = 200; // 楕円の中心X座標
  let centerY = 200; // 楕円の中心Y座標
  let angle = 0

  function moveElement() {
    let x = centerX + Math.cos(angle) * radiusX;
    let y = centerY + Math.sin(angle) * radiusY;
    element.style.left = x + 'px';
    element.style.top = y + 'px';
    angle += 0.03; // アニメーションの速度を調整するための角度変化
    requestAnimationFrame(moveElement);
  }

  moveElement();
}