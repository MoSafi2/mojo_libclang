/* examples/acme_image.h */
#ifndef ACME_IMAGE_H
#define ACME_IMAGE_H

#ifdef __cplusplus
extern "C" {
#endif

typedef enum AcmeStatus {
ACME_OK = 0,
ACME_ERROR_INVALID_ARGUMENT = 1,
ACME_ERROR_IO = 2,
ACME_ERROR_UNSUPPORTED_FORMAT = 3,
} AcmeStatus;

typedef struct AcmeImage {
int width;
int height;
int channels;
unsigned char* pixels;
} AcmeImage;

typedef struct AcmeResizeOptions {
int target_width;
int target_height;
int preserve_aspect_ratio;
} AcmeResizeOptions;

AcmeImage* acme_image_open(const char* path);

void acme_image_free(AcmeImage* image);

AcmeStatus acme_image_resize(
AcmeImage* image,
const AcmeResizeOptions* options
);

AcmeStatus acme_image_write_png(
const AcmeImage* image,
const char* path
);

#ifdef __cplusplus
}
#endif

#endif
