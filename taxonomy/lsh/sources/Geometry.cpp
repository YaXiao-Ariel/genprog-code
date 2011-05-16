/*
 * Copyright (c) 2004-2005 Massachusetts Institute of Technology.
 * All Rights Reserved.
 *
 * MIT grants permission to use, copy, modify, and distribute this software and
 * its documentation for NON-COMMERCIAL purposes and without fee, provided that
 * this copyright notice appears in all copies.
 *
 * MIT provides this software "as is," without representations or warranties of
 * any kind, either expressed or implied, including but not limited to the
 * implied warranties of merchantability, fitness for a particular purpose, and
 * noninfringement.  MIT shall not be liable for any damages arising from any
 * use of this software.
 *
 * Author: Alexandr Andoni (andoni@mit.edu), Piotr Indyk (indyk@mit.edu)
 */

#include "headers.h"

// Returns the Euclidean distance from point <p1> to <p2>.
RealT distance(IntT dimension, PointT * p1, PointT * p2){
  RealT result = 0;

  for (IntT i = 0; i < dimension; i++){
    result += SQR(p1->coordinates[i] - p2->coordinates[i]);
  }

  return SQRT(result);
}


int comparePoints(const void *p1, const void *p2)
{
    PointT * a = (PointT *) p1;
    PointT * b = (PointT *)p2;
    int c = strcmp(a->cprop[ENUM_CPROP_FILE], b->cprop[ENUM_CPROP_FILE]);
    if (c) return c;
    else {
        c =  a->iprop[ENUM_PPROP_TID] - b->iprop[ENUM_PPROP_TID];
        if(c) return c;
        else return (int) (a->distance - b->distance);
    }
}

void printPoint(PointT * point) {
    printf("Point index: %05d\t TID:%d\tBENCH: %s \tFILE %s\tREVNUM: %d\tMSG:%s\n",
           point->index, 
           point->iprop[ENUM_PPROP_TID],
           point->cprop[ENUM_CPROP_BENCH],
           point->cprop[ENUM_CPROP_FILE],
           point->iprop[ENUM_PPROP_REVNUM],
           point->cprop[ENUM_CPROP_MSG]);

}
