# Permissions in Test Environment
`use dojo::model::{ModelStorage, ModelStorageTest};`
`use dojo_cairo_test::{WorldStorageTestTrait};`

Import above and use `world.write_model_test(@model);` when writing model storage for tests.