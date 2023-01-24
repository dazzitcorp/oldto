export let LOCATIONS = {}

export let locationsReady = fetch('/api/locations.json')
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
