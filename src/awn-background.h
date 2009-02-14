/*
 *  Copyright (C) 2008 Neil Jagdish Patel <njpatel@gmail.com>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301  USA.
 *
 *  Author : Neil Jagdish Patel <njpatel@gmail.com>
*/

#ifndef	_AWN_BACKGROUND_H
#define	_AWN_BACKGROUND_H

#include <glib.h>
#include <glib-object.h>
#include <gtk/gtk.h>

#include <libawn/awn-cairo-utils.h>
#include <libawn/awn-config-client.h>

#include "awn-panel.h"

G_BEGIN_DECLS

#define AWN_TYPE_BACKGROUND (awn_background_get_type())

#define AWN_BACKGROUND(obj) (G_TYPE_CHECK_INSTANCE_CAST ((obj), AWN_TYPE_BACKGROUND, \
  AwnBackground))

#define AWN_BACKGROUND_CLASS(obj)	(G_TYPE_CHECK_CLASS_CAST ((obj), AWN_TYPE_BACKGROUND, \
  AwnBackgroundClass))

#define AWN_IS_BACKGROUND(obj) (G_TYPE_CHECK_INSTANCE_TYPE ((obj), AWN_TYPE_BACKGROUND))

#define AWN_IS_BACKGROUND_CLASS(obj) (G_TYPE_CHECK_CLASS_TYPE ((obj), \
  AWN_TYPE_BACKGROUND))

#define AWN_BACKGROUND_GET_CLASS(obj)	(G_TYPE_INSTANCE_GET_CLASS ((obj), \
  AWN_TYPE_BACKGROUND, AwnBackgroundClass))

typedef struct _AwnBackground AwnBackground;
typedef struct _AwnBackgroundClass AwnBackgroundClass;

struct _AwnBackground 
{
  GObject  parent;

  AwnConfigClient *client;
  AwnPanel        *panel;

  /* Standard box drawing colours */
  AwnColor g_step_1;
  AwnColor g_step_2;
  AwnColor g_histep_1;
  AwnColor g_histep_2;
  AwnColor border_color;
  AwnColor hilight_color;

  /* Separator options */
  gboolean show_sep;
  AwnColor sep_color;

  /* Pattern options */
  gboolean   enable_pattern;
  gfloat     pattern_alpha;
  GdkPixbuf *pattern;

  /* Appearance options -- (some are backend specific) */
  gboolean gtk_theme_mode;
  gboolean rounded_corners;
  gfloat   corner_radius;
  gint     panel_angle;
  gfloat   curviness;
  gfloat   curves_symmetry;

  /* private */
  guint    changed;
};

struct _AwnBackgroundClass 
{
  GObjectClass parent_class;

  /*< vtable >*/
  void (*draw) (AwnBackground  *bg,
                cairo_t        *cr, 
                AwnOrientation  orient,
                GdkRectangle   *area);

  void (*padding_request) (AwnBackground *bg,
                           AwnOrientation orient,
                           guint *padding_top,
                           guint *padding_bottom,
                           guint *padding_left,
                           guint *padding_right);

  void (*get_shape_mask) (AwnBackground *bg,
                          cairo_t        *cr,
                          AwnOrientation  orient,
                          GdkRectangle   *area);

  void (*get_input_shape_mask) (AwnBackground *bg,
                                cairo_t        *cr,
                                AwnOrientation  orient,
                                GdkRectangle   *area);

  /*< signals >*/
  void (*changed) (AwnBackground *bg);
  void (*padding_changed) (AwnBackground *bg);
};

GType awn_background_get_type (void) G_GNUC_CONST;

void awn_background_draw      (AwnBackground  *bg,
                               cairo_t        *cr, 
                               AwnOrientation  orient,
                               GdkRectangle   *area);

void awn_background_padding_request (AwnBackground *bg,
                                     AwnOrientation orient,
                                     guint *padding_top,
                                     guint *padding_bottom,
                                     guint *padding_left,
                                     guint *padding_right);

void awn_background_get_shape_mask (AwnBackground  *bg,
                                    cairo_t        *cr,
                                    AwnOrientation  orient,
                                    GdkRectangle   *area);

void awn_background_get_input_shape_mask (AwnBackground  *bg,
                                          cairo_t        *cr,
                                          AwnOrientation  orient,
                                          GdkRectangle   *area);

/* This one should be "protected" (used only be derived classes) */
void awn_background_emit_padding_changed (AwnBackground *bg);

G_END_DECLS

#endif /* _AWN_BACKGROUND_H */

