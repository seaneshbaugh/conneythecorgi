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
  window.addEventListener("resize", resizeAllGridItems);

  const grid = document.querySelector(".grid");

  grid.querySelectorAll(".item").forEach((item) => {
    imagesLoaded(item, () => {
      resizeGridItem(grid, item);
    });
  });
});
