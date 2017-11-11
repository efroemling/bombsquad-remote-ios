IMAGE_RESOURCE_INST_DIR = ../Resources/Images
IMAGE_WEB_INST_DIR = ../WebResources/Images

IMAGE_RESOURCE_SOURCES = $(wildcard ImagesResource/*.psd)
IMAGE_RESOURCE_TARGETS = $(subst ImagesResource, $(IMAGE_RESOURCE_INST_DIR), $(subst .psd,.png,$(IMAGE_RESOURCE_SOURCES)))

IMAGE_RESOURCE_RETINA_SOURCES = $(wildcard ImagesResourceRetina/*.psd)
IMAGE_RESOURCE_RETINA_TARGETS = $(subst ImagesResourceRetina, $(IMAGE_RESOURCE_INST_DIR), $(subst .psd,.png,$(IMAGE_RESOURCE_RETINA_SOURCES)))
IMAGE_RESOURCE_RETINA_TARGETS_HI = $(subst ImagesResourceRetina, $(IMAGE_RESOURCE_INST_DIR), $(subst .psd,@2x.png,$(IMAGE_RESOURCE_RETINA_SOURCES)))

IMAGE_RESOURCE_RETINA_IPAD_SOURCES = $(wildcard ImagesResourceRetinaIpad/*.psd)
IMAGE_RESOURCE_RETINA_IPAD_TARGETS = $(subst ImagesResourceRetinaIpad, $(IMAGE_RESOURCE_INST_DIR), $(subst .psd,~ipad.png,$(IMAGE_RESOURCE_RETINA_IPAD_SOURCES)))
IMAGE_RESOURCE_RETINA_IPAD_TARGETS_HI = $(subst ImagesResourceRetinaIpad, $(IMAGE_RESOURCE_INST_DIR), $(subst .psd,@2x~ipad.png,$(IMAGE_RESOURCE_RETINA_IPAD_SOURCES)))

IMAGE_WEB_SOURCES = $(wildcard ImagesWeb/*.psd)
IMAGE_WEB_TARGETS = $(subst ImagesWeb, $(IMAGE_WEB_INST_DIR), $(subst .psd,.png,$(IMAGE_WEB_SOURCES)))

ICON_TARGETS = $(IMAGE_RESOURCE_INST_DIR)/Icon.png\
               $(IMAGE_RESOURCE_INST_DIR)/Icon@2x.png\
               $(IMAGE_RESOURCE_INST_DIR)/Icon-60.png\
               $(IMAGE_RESOURCE_INST_DIR)/Icon-60@2x.png\
               $(IMAGE_RESOURCE_INST_DIR)/Icon-72.png\
               $(IMAGE_RESOURCE_INST_DIR)/Icon-72@2x.png\
               $(IMAGE_RESOURCE_INST_DIR)/Icon-76.png\
               $(IMAGE_RESOURCE_INST_DIR)/Icon-76@2x.png\
               $(IMAGE_RESOURCE_INST_DIR)/Icon-Small.png\
               $(IMAGE_RESOURCE_INST_DIR)/Icon-Small@2x.png\
               $(IMAGE_RESOURCE_INST_DIR)/Icon-Small-40.png\
               $(IMAGE_RESOURCE_INST_DIR)/Icon-Small-40@2x.png\
               $(IMAGE_RESOURCE_INST_DIR)/Icon-Small-50.png\
               $(IMAGE_RESOURCE_INST_DIR)/Icon-Small-50@2x.png\
               $(IMAGE_WEB_INST_DIR)/IconItunes.png\
               $(IMAGE_WEB_INST_DIR)/IconItunes1kFlat.png

# resource images
$(IMAGE_RESOURCE_INST_DIR)/%.png : ImagesResource/%.psd
	@echo Creating image: $@
	@./convertUtil convertImage $^ $@

# retina resource images 1x
$(IMAGE_RESOURCE_INST_DIR)/%.png : ImagesResourceRetina/%.psd
	@echo Creating image: $@
	@./convertUtil convertImageHalf $^ $@

# retina resource images 2x
$(IMAGE_RESOURCE_INST_DIR)/%@2x.png : ImagesResourceRetina/%.psd
	@echo Creating image: $@
	@./convertUtil convertImage $^ $@

# retina ipad resource images 1x
$(IMAGE_RESOURCE_INST_DIR)/%~ipad.png : ImagesResourceRetinaIpad/%.psd
	@echo Creating image: $@
	@./convertUtil convertImageHalf $^ $@

# retina ipad resource images 2x
$(IMAGE_RESOURCE_INST_DIR)/%@2x~ipad.png : ImagesResourceRetinaIpad/%.psd
	@echo Creating image: $@
	@./convertUtil convertImage $^ $@

# web images
$(IMAGE_WEB_INST_DIR)/%.png : ImagesWeb/%.psd
	@echo Creating image: $@
	@./convertUtil convertImage $^ $@

all: $(ICON_TARGETS)\
     $(IMAGE_RESOURCE_TARGETS)\
     $(IMAGE_RESOURCE_RETINA_TARGETS)\
     $(IMAGE_RESOURCE_RETINA_TARGETS_HI)\
     $(IMAGE_RESOURCE_RETINA_IPAD_TARGETS)\
     $(IMAGE_RESOURCE_RETINA_IPAD_TARGETS_HI)\
     $(IMAGE_WEB_TARGETS)

# icon files
$(IMAGE_RESOURCE_INST_DIR)/Icon.png: ImagesMisc/Icon.psd
	@echo Creating image: $@
	@./convertUtil convertImageToSize 57 57 ImagesMisc/Icon.psd $(IMAGE_RESOURCE_INST_DIR)/Icon.png
$(IMAGE_RESOURCE_INST_DIR)/Icon@2x.png: ImagesMisc/Icon.psd
	@echo Creating image: $@
	@./convertUtil convertImageToSize 114 114 ImagesMisc/Icon.psd $(IMAGE_RESOURCE_INST_DIR)/Icon@2x.png
$(IMAGE_RESOURCE_INST_DIR)/Icon-60.png: ImagesMisc/Icon.psd
	@echo Creating image: $@
	@./convertUtil convertImageToSize 60 60 ImagesMisc/Icon.psd $(IMAGE_RESOURCE_INST_DIR)/Icon-60.png
$(IMAGE_RESOURCE_INST_DIR)/Icon-60@2x.png: ImagesMisc/Icon.psd
	@echo Creating image: $@
	@./convertUtil convertImageToSize 120 120 ImagesMisc/Icon.psd $(IMAGE_RESOURCE_INST_DIR)/Icon-60@2x.png
$(IMAGE_RESOURCE_INST_DIR)/Icon-72.png: ImagesMisc/Icon.psd
	@echo Creating image: $@
	@./convertUtil convertImageToSize 72 72 ImagesMisc/Icon.psd $(IMAGE_RESOURCE_INST_DIR)/Icon-72.png
$(IMAGE_RESOURCE_INST_DIR)/Icon-72@2x.png: ImagesMisc/Icon.psd
	@echo Creating image: $@
	@./convertUtil convertImageToSize 144 144 ImagesMisc/Icon.psd $(IMAGE_RESOURCE_INST_DIR)/Icon-72@2x.png
$(IMAGE_RESOURCE_INST_DIR)/Icon-76.png: ImagesMisc/Icon.psd
	@echo Creating image: $@
	@./convertUtil convertImageToSize 76 76 ImagesMisc/Icon.psd $(IMAGE_RESOURCE_INST_DIR)/Icon-76.png
$(IMAGE_RESOURCE_INST_DIR)/Icon-76@2x.png: ImagesMisc/Icon.psd
	@echo Creating image: $@
	@./convertUtil convertImageToSize 152 152 ImagesMisc/Icon.psd $(IMAGE_RESOURCE_INST_DIR)/Icon-76@2x.png
$(IMAGE_RESOURCE_INST_DIR)/Icon-Small.png: ImagesMisc/Icon.psd
	@echo Creating image: $@
	@./convertUtil convertImageToSize 29 29 ImagesMisc/Icon.psd $(IMAGE_RESOURCE_INST_DIR)/Icon-Small.png
$(IMAGE_RESOURCE_INST_DIR)/Icon-Small@2x.png: ImagesMisc/Icon.psd
	@echo Creating image: $@
	@./convertUtil convertImageToSize 58 58 ImagesMisc/Icon.psd $(IMAGE_RESOURCE_INST_DIR)/Icon-Small@2x.png
$(IMAGE_RESOURCE_INST_DIR)/Icon-Small-40.png: ImagesMisc/Icon.psd
	@echo Creating image: $@
	@./convertUtil convertImageToSize 40 40 ImagesMisc/Icon.psd $(IMAGE_RESOURCE_INST_DIR)/Icon-Small-40.png
$(IMAGE_RESOURCE_INST_DIR)/Icon-Small-40@2x.png: ImagesMisc/Icon.psd
	@echo Creating image: $@
	@./convertUtil convertImageToSize 80 80 ImagesMisc/Icon.psd $(IMAGE_RESOURCE_INST_DIR)/Icon-Small-40@2x.png
$(IMAGE_RESOURCE_INST_DIR)/Icon-Small-50.png: ImagesMisc/Icon.psd
	@echo Creating image: $@
	@./convertUtil convertImageToSize 50 50 ImagesMisc/Icon.psd $(IMAGE_RESOURCE_INST_DIR)/Icon-Small-50.png
$(IMAGE_RESOURCE_INST_DIR)/Icon-Small-50@2x.png: ImagesMisc/Icon.psd
	@echo Creating image: $@
	@./convertUtil convertImageToSize 100 100 ImagesMisc/Icon.psd $(IMAGE_RESOURCE_INST_DIR)/Icon-Small-50@2x.png
$(IMAGE_WEB_INST_DIR)/IconItunes.png: ImagesMisc/Icon.psd
	@echo Creating image: $@
	@./convertUtil convertImage ImagesMisc/Icon.psd $(IMAGE_WEB_INST_DIR)/IconItunes.png
$(IMAGE_WEB_INST_DIR)/IconItunes1kFlat.png: ImagesMisc/Icon.psd
	@echo Creating image: $@
	@./convertUtil convertImage ImagesMisc/Icon.psd $(IMAGE_WEB_INST_DIR)/IconItunes1kFlat.png

# clean:
# 	rm -rf $(IMAGE_RESOURCE_INST_DIR)/*
# 	rm -rf $(IMAGE_WEB_INST_DIR)/*
