#include <stdio.h>

#define CHARS 256
#define NULL 0

typedef unsigned long Pos;

/* suffix tree for storing GFF seqnames */
typedef struct Suffix_str {
  char* prefix;
  void* next[CHARS];
} Suffix;

/* quad tree for storing GFF coords */
typedef struct Quad_str {
  Pos xmin, ymin, size;
  void** child;
} Quad;

/* singly linked list for storing file positions of GFF records */
typedef struct List_str {
  void* data;
  void* next;
} List;

/* Quad visitor function */
typedef void (*Visitor) (void*, Quad*);

/* function prototypes */
Quad* newQuad (Pos x, Pos y, Pos size);
Quad* newRootQuad();
void freeQuad (Quad* quad);

int childIndex (Quad* quad, Pos x, Pos y);
Quad* getChild (Quad* quad, int i);
void setChild (Quad* quad, int i, Quad* child);

int children (Quad* quad);

Pos xmid (Quad* quad);
Pos ymid (Quad* quad);
Pos xmax (Quad* quad);
Pos ymax (Quad* quad);

void addLeaf (Quad** root, Pos x, Pos y, void* data);
void iterate (Quad* quad, Pos xmin, Pos ymin, Pos xmax, Pos ymax,
	      void* visitorContext, Visitor visitor);
Suffix* readGFF (FILE* file);
Suffix* intersect (Suffix* file1, Suffix* file2);



/* function definitions */
Suffix* readGFF (FILE* file) {
  Suffix *root;
  
  root = 0;
  
  return root;
}
