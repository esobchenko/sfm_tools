# GNU Make implementation of my OpenMVG-OpenMVS SfM pipeline
# usage:
#        make -f sfm.mk IN=./input_dataset OUT=./output
#
# -eugen, esobchenko@gmail.com

OPENMVG_BIN				?= "/home/eugen/devel/photogrammetry/bin"
OPENMVS_BIN				?= "/home/eugen/devel/photogrammetry/bin"

SENSORS_DATABASE 		?= "/home/eugen/devel/photogrammetry/sensor_width_camera_database.txt"

IN						?= "./in"
OUT						?= "./out"

MATCHES_DIR				= $(abspath $(OUT))/matches
RECONSTRUCTION_DIR		= $(abspath $(OUT))/reconstruction
MVS_DIR					= $(abspath $(OUT))/mvs

.PHONY: all

all: $(OUT)/texture_mesh.done

# 1. Image listing
$(OUT)/image_listing.done:
	@test -d $(IN) || (>&2 echo "Input directory '$(IN)' doesn't exists" && exit 1)
	mkdir -p $(OUT) $(MATCHES_DIR) $(RECONSTRUCTION_DIR) $(MVS_DIR)
	$(OPENMVG_BIN)/openMVG_main_SfMInit_ImageListing -i $(IN) -o $(MATCHES_DIR) -d $(SENSORS_DATABASE)
	touch $@

# 2. Image description computation
$(OUT)/compute_features.done: $(OUT)/image_listing.done
	$(OPENMVG_BIN)/openMVG_main_ComputeFeatures -i $(MATCHES_DIR)/sfm_data.json -o $(MATCHES_DIR) -m SIFT -n 4 -p NORMAL
	touch $@

# 3. Compute matches
$(OUT)/compute_matches.done: $(OUT)/compute_features.done
	$(OPENMVG_BIN)/openMVG_main_ComputeMatches -i $(MATCHES_DIR)/sfm_data.json -o $(MATCHES_DIR)
	touch $@

# 4. Incremental reconstruction
$(OUT)/reconstruction.done: $(OUT)/compute_matches.done
	$(OPENMVG_BIN)/openMVG_main_IncrementalSfM -i $(MATCHES_DIR)/sfm_data.json -m $(MATCHES_DIR) -o $(RECONSTRUCTION_DIR)
	touch $@

# 5. Colorize structure
$(OUT)/colorize_structure.done: $(OUT)/reconstruction.done
	$(OPENMVG_BIN)/openMVG_main_ComputeSfM_DataColor -i $(RECONSTRUCTION_DIR)/sfm_data.bin -o $(RECONSTRUCTION_DIR)/colorized.ply
	touch $@

# 6. Structure from Known Poses
$(OUT)/struct_known_poses.done: $(OUT)/colorize_structure.done
	$(OPENMVG_BIN)/openMVG_main_ComputeStructureFromKnownPoses -i $(RECONSTRUCTION_DIR)/sfm_data.bin -m $(MATCHES_DIR) -f $(MATCHES_DIR)/matches.f.bin -o $(RECONSTRUCTION_DIR)/robust.bin
	touch $@

# 7. Colorized robust triangulation
$(OUT)/robust_triangulation.done: $(OUT)/struct_known_poses.done
	$(OPENMVG_BIN)/openMVG_main_ComputeSfM_DataColor -i $(RECONSTRUCTION_DIR)/robust.bin -o $(RECONSTRUCTION_DIR)/robust_colorized.ply
	touch $@

# 8. Export to MVS
$(OUT)/export_to_mvs.done: $(OUT)/robust_triangulation.done
	$(OPENMVG_BIN)/openMVG_main_openMVG2openMVS -i $(RECONSTRUCTION_DIR)/sfm_data.bin -o $(MVS_DIR)/scene.mvs -d $(MVS_DIR)
	touch $@

# 9. Densify point cloud
$(OUT)/densify_point_cloud.done: $(OUT)/export_to_mvs.done
	$(OPENMVS_BIN)/DensifyPointCloud scene.mvs -w $(MVS_DIR) --resolution-level 1
	touch $@

# 10. Reconstruct the mesh
$(OUT)/reconstruct_mesh.done: $(OUT)/densify_point_cloud.done
	$(OPENMVS_BIN)/ReconstructMesh scene_dense.mvs -w $(MVS_DIR)
	touch $@

# 11. Refine the mesh
$(OUT)/refine_mesh.done: $(OUT)/reconstruct_mesh.done
	$(OPENMVS_BIN)/RefineMesh scene_dense_mesh.mvs -w $(MVS_DIR)
	touch $@

# 12. Texture the mesh
$(OUT)/texture_mesh.done: $(OUT)/refine_mesh.done
	$(OPENMVS_BIN)/TextureMesh scene_dense_mesh_refine.mvs -w $(MVS_DIR)
	touch $@

clean:
	rm -rf $(OUT)
