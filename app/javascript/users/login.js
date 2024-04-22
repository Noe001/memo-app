window.onload = function() {
  let element = document.getElementById('circle_1');
  let radiusX = 400; // X軸半径
  let radiusY = 200;  // Y軸半径
  let centerX = 1160; // 楕円の中心X座標
  let centerY = 500; // 楕円の中心Y座標
  let angle = 0

  function moveElement() {
    let x = centerX + Math.cos(angle) * radiusX;
    let y = centerY + Math.sin(angle) * radiusY;
    element.style.left = x + 'px';
    element.style.top = y + 'px';
    element.style.overflow = 'hidden';
    angle += 0.007; // アニメーションの速度を調整するための角度変化
    requestAnimationFrame(moveElement);
  }

  moveElement();
}