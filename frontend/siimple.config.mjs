import base from "@siimple/preset-base";
import colors from "@siimple/colors";

export default {
  modules: {
    // Setting a module to `true` doesn't enable it!
    // But mentioning it apparently *dis*ables it...
    alert: false,
    badge: false,
    button: false,
    card: false,
    checkbox: false,
    close: false,
    // container: false,
    column: false,
    crumb: false,
    dropdown: false,
    input: false,
    label: false,
    menu: false,
    modal: false,
    navlink: false,
    progress: false,
    radio: false,
    scrim: false,
    select: false,
    slider: false,
    spinner: false,
    switch: false,
    textarea: false,
  },
  ...base,
  colors: {
      ...base.colors,
      // primaryLighter: "#38b7d3",
      primary: "#1272ce",  // Match Maps
      // primaryDarker: "#075aa9",
      // secondaryLighter: colors.pink["400"],
      secondary: colors.pink["500"],
      // secondaryDarker: colors.pink["600"],
      highlight: "#38b7d3",  // primaryLighter
      muted: colors.neutral["300"],
  },
  fontWeights: {
    body: "400",
    heading: "900",
  },
  text: {
    link: {
      color: "primary",
      "&:hover": {
        color: "secondary",
      },
    },
  },
  styles: {
    ".button-link": {
      backgroundColor: "primary",
      color: "white",
      fontSize: "10px",
      fontWeight: "600",
      lineHeight: "1",
      padding: "6px 12px",
      textDecoration: "none",
      textTransform: "uppercase",
      "&:hover": {
        color: "white",
      },
    },
    ".has-gap-1": {
      gap: "1rem",
    },
    ".is-readable": {
      maxWidth: "45rem",  // 45rem * 16px = 720px
    },
  },
};
