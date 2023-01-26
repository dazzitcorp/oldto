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
    // navlink: false,
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
      primary: colors.blue["500"],
      primaryDarker: colors.blue["600"],
      secondary: colors.pink["500"],
      secondaryDarker: colors.pink["600"],
      highlight: colors.blue["300"],
      muted: colors.neutral["300"],
  },
  fontWeights: {
    heading: "900",
  },
  links: {
    nav: {
      color: "text",
      "&:hover": {
        color: "primary",
      },
      fontWeight: "medium",
    },
  },
  text: {
    link: {
      color: "secondary",
      "&:hover": {
        color: "secondaryDarker",
      },
    },
  },
  styles: {
    ".has-gap-1": {
      gap: "1rem",
    },
    ".is-readable": {
      maxWidth: "45rem",  // 45rem * 16px = 720px
    },
  },
};
