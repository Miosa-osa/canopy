// Unit tests must provide their own API responses instead of depending on a
// developer's running backend or sending requests to it.
globalThis.fetch = async () => {
  throw new Error('Unexpected network request: mock fetch explicitly in this unit test.');
};
