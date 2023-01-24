export let IMAGES = {}
export let LOCATIONS = {}

export let imagesReady = fetch('/api/images_ex.json')
  .then((response) => {
    if (response.ok) {
      return response.json()
    } else {
      console.error(response)
      return {}
    }
  }).then((result) => {
    IMAGES = result
  })

export let locationsReady = fetch('/api/locations_ex.json')
  .then((response) => {
    if (response.ok) {
      return response.json()
    } else {
      console.error(response)
      return {}
    }
  }).then((result) => {
    LOCATIONS = result
  })
