Merges multiple effects into one. This will result in an effect that will execute the given effects in parallel, with subscription starting with the order provided but delivering output values in the order they arrive from any of the merged effects.

- Parameters:
  - first: any effect to have its elements merged into the final effect stream
  - second: any effect to have its elements merged into the final effect stream
  - third: any effect to have its elements merged into the final effect stream
  - fourth: any effect to have its elements merged into the final effect stream
  - fifth: any effect to have its elements merged into the final effect stream
- Returns: an Effect that will subscribe to all upstream effects provided above, and will combine their elements as they arrive.