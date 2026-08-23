#include "../include/Scene.h"
#include "../include/Entity.h"
#include "../include/Entity_Components.h"
#include "../include/systems/PhysicsEngine.h"
#include "../src/components/InfiniteGrid.h"
#include "../src/components/Sun.h"
#include "glm/trigonometric.hpp"
Scene::Scene(unsigned int cubeVAO) {
  createGround();
  createTree(glm::vec3(0.0f, 0.0f, 0.0f));
  createSun(cubeVAO);
  createGrid();
  for (int i = 0; i < 5; i++) {
    createTestCube(glm::vec3(5.0, 0.0f, (5.0f + 0.25 * i)));
  }
  //   // createGrass(glm::vec3((5.0f + 0.25 * i), 0.0f, (5.0f + 0.25 * i)));
  //   // createGrass(glm::vec3((5.0f + 0.25 * i), 0.0f, (5.0f + 0.25 * i)));
  //   // createGrass(glm::vec3((5.0f - 0.25 * i), 0.0f, (5.0f - 0.25 * i)));
  //   // createGrass(glm::vec3((5.0f - 0.25 * i), 0.0f, (5.0f + 0.25 * i)));
  //   // createGrass(glm::vec3((5.0f + 0.25 * i), 0.0f, (5.0f - 0.25 * i)));
  // }
  LOG_INFO("Scene: all entities created");
}

Scene::~Scene() {
  for (auto& [key, shader] : shaderCache) {
    delete shader;
  }
  shaderCache.clear();

  auto sunView = reg.view<SunComponent>();
  for (auto e : sunView) {
    delete sunView.get<SunComponent>(e).sun;
    sunView.get<SunComponent>(e).sun = nullptr;
  }

  auto gridView = reg.view<InfiniteGridComponent>();
  for (auto e : gridView) {
    delete gridView.get<InfiniteGridComponent>(e).grid;
    gridView.get<InfiniteGridComponent>(e).grid = nullptr;
  }

  auto meshView = reg.view<MeshRendererComponent>();
  for (auto e : meshView) {
    auto &mr = meshView.get<MeshRendererComponent>(e);
    delete mr.model;
    mr.model = nullptr;
    mr.shader = nullptr;
  }

  LOG_WARN("Scene: all entity resources cleaned up");
}

Shader* Scene::getOrCreateShader(const std::string& vs, const std::string& fs) {
  std::string key = vs + "|" + fs;
  auto it = shaderCache.find(key);
  if (it != shaderCache.end()) return it->second;
  Shader* s = new Shader(vs, fs);
  shaderCache[key] = s;
  return s;
}

Entity Scene::createEntity() {
  auto e = reg.create();
  auto entity = Entity(e, this);
  entity.addComponent<IDComponent>(generateUUID());
  return entity;
}

void Scene::update(Camera &camera) {
  auto sunView = reg.view<SunComponent>();
  for (auto entity : sunView) {
    auto &sc = sunView.get<SunComponent>(entity);
    if (sc.sun) {
      sc.sun->update(camera);
    }
  }
  engine.update(*this);
}

Entity Scene::createGround() {
  Entity ground = createEntity();
  // ground.addComponent<IDComponent>(generateUUID());
  auto &transform = ground.addComponent<TransformComponent>();
  transform.position = {0.0f, 0.0f, 0.0f};
  auto &rb = ground.addComponent<RigidBodyComponent>();
  using namespace reactphysics3d;
  Transform physicsTransform(Vector3(0, -1, 0), Quaternion::identity());
  rb.body = engine.world->createRigidBody(physicsTransform);
  rb.body->setType(BodyType::STATIC);
  CollisionShape *shape = engine.pCommon.createBoxShape(Vector3(100.0f, 1.0f, 100.0f));
  rb.body->addCollider(shape, Transform::identity());
  return ground;
}

Entity Scene::createTree(glm::vec3 pos) {
  Entity tree = createEntity();
  //tree.addComponent<IDComponent>(generateUUID());

  tree.addComponent<TagComponent>(TagComponent{"Tree"});
  auto &transform = tree.addComponent<TransformComponent>();
  transform.position = pos;
  transform.rotation = glm::radians(glm::vec3(-90.0f, 0.0f, 0.0f));
  transform.scale = glm::vec3(0.01f);
  auto &rb = tree.addComponent<RigidBodyComponent>();
  using namespace reactphysics3d;
  Transform physicsTransform(
      Vector3(transform.position.x, transform.position.y, transform.position.z),
      Quaternion::fromEulerAngles(transform.rotation.x, transform.rotation.y, transform.rotation.z));
  rb.body = engine.world->createRigidBody(physicsTransform);
  rb.body->setType(BodyType::STATIC);
  CollisionShape *shape = engine.pCommon.createCapsuleShape(1.0f, 3.0f);
  rb.body->addCollider(shape, Transform::identity());
  auto &meshRenderer = tree.addComponent<MeshRendererComponent>();
  meshRenderer.model = new Model("../external/models/maple_tree/scene.gltf");
  meshRenderer.shader = getOrCreateShader("../src/components/shaders/tree.vs",
                                          "../src/components/shaders/tree.fs");
  return tree;
}
Entity Scene::createSun(unsigned int cubeVAO) {
  Entity sunEntity = createEntity();
  //sunEntity.addComponent<IDComponent>(generateUUID());
  sunEntity.addComponent<TagComponent>(TagComponent{"Sun"});
  auto &sc = sunEntity.addComponent<SunComponent>();
  sc.sun = new Sun(cubeVAO);
  LOG_INFO("Scene: Sun entity created");
  return sunEntity;
}

Entity Scene::createGrid() {
  Entity gridEntity = createEntity();
  //gridEntity.addComponent<IDComponent>(generateUUID());
  gridEntity.addComponent<TagComponent>(TagComponent{"Grid"});
  auto &gc = gridEntity.addComponent<InfiniteGridComponent>();
  gc.grid = new InfiniteGrid();
  LOG_INFO("Scene: Grid entity created");
  return gridEntity;
}

// Entity Scene::createGrass(glm::vec3 pos) {
//   Entity grass = createEntity();
//   grass.addComponent<TagComponent>(TagComponent{"Grass"});
//   auto &transform = grass.addComponent<TransformComponent>();
//   transform.position = pos;
//   transform.rotation = glm::radians(glm::vec3(-90.0f, 0.0f, 0.0f));
//   transform.scale = glm::vec3(0.0001f);
//
//   auto &rb = grass.addComponent<RigidBodyComponent>();
//   using namespace reactphysics3d;
//   Transform physicsTransform(
//       Vector3(transform.position.x, transform.position.y, transform.position.z),
//       Quaternion::fromEulerAngles(transform.rotation.x, transform.rotation.y, transform.rotation.z));
//   rb.body = engine.world->createRigidBody(physicsTransform);
//   rb.body->setType(BodyType::STATIC);
//
//   auto &meshRenderer = grass.addComponent<MeshRendererComponent>();
//   meshRenderer.model = new Model("../external/models/grass/scene.gltf");
//   meshRenderer.shader = getOrCreateShader("../src/components/shaders/tree.vs",
//                                           "../src/components/shaders/tree.fs");
//   return grass;
// }

Entity Scene::createTestCube(glm::vec3 pos) {
  Entity cube = createEntity();
  LOG_WARN("TEST CUBE CREATED");
  auto &transform = cube.addComponent<TransformComponent>();
  transform.position = pos;
  transform.scale = glm::vec3(0.1f);

  auto &meshRenderer = cube.addComponent<MeshRendererComponent>();
  meshRenderer.model = new Model("../external/models/cube/scene.gltf");
  meshRenderer.shader = getOrCreateShader("../src/components/shaders/tree.vs",
                                          "../src/components/shaders/tree.fs");

  auto &rb = cube.addComponent<RigidBodyComponent>();
  using namespace reactphysics3d;
  Transform t(Vector3(pos.x, pos.y, pos.z), Quaternion::identity());
  rb.body = engine.world->createRigidBody(t);
  rb.body->setType(BodyType::DYNAMIC);
  CollisionShape *shape = engine.pCommon.createBoxShape(Vector3(0.5f, 0.5f, 0.5f));
  rb.body->addCollider(shape, Transform::identity());
  return cube;
}