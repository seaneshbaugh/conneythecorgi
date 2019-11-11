import "materialize-css/dist/js/materialize.js";
import "material-design-icons/iconfont/MaterialIcons-Regular.woff2";
import "material-design-icons/iconfont/MaterialIcons-Regular.woff";
import "material-design-icons/iconfont/MaterialIcons-Regular.ttf";
import imagesLoaded from "imagesloaded";

const onReady = (completed) => {
  if (document.readyState === "complete") {
    setTimeout(completed);
  } else {
    document.addEventListener("DOMContentLoaded", completed, false);
  }
};

const resizeGridItem = (grid, item) => {
  const rowHeight = parseInt(window.getComputedStyle(grid).getPropertyValue("grid-auto-rows"));
  const rowGap = parseInt(window.getComputedStyle(grid).getPropertyValue("grid-row-gap"));
  const rowSpan = Math.ceil((item.querySelector(".content").getBoundingClientRect().height + rowGap) / (rowHeight + rowGap));

  item.style.gridRowEnd = `span ${rowSpan}`;
};

const resizeAllGridItems = () => {
  const grid = document.querySelector(".grid");

  grid.querySelectorAll(".item").forEach((item) => {
    resizeGridItem(grid, item);
  });
};

onReady(() => {
  M.AutoInit();

  const grid = document.querySelector(".grid");

  if (!grid) {
    return;
  }

  window.addEventListener("resize", resizeAllGridItems);

  grid.querySelectorAll(".item").forEach((item) => {
    imagesLoaded(item, () => {
      resizeGridItem(grid, item);
    });
  });
});
