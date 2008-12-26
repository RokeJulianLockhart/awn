/*
 *  Copyright (C) 2007 Michal Hruby <michal.mhr@gmail.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#include "awn-effects-shared.h"

gboolean
awn_effect_check_top_effect(AwnEffectsAnimation * anim, gboolean * stopped)
{
  if (stopped)
    *stopped = TRUE;

  AwnEffectsPrivate *priv = anim->effects->priv;

  GList *queue = priv->effect_queue;

  AwnEffectsAnimation *item;

  while (queue)
  {
    item = queue->data;

    if (item->this_effect == anim->this_effect)
    {
      if (stopped)
        *stopped = FALSE;

      break;
    }

    queue = g_list_next(queue);
  }

  if (!priv->effect_queue)
    return FALSE;

  item = priv->effect_queue->data;

  return item->this_effect == anim->this_effect;
}


gboolean
awn_effect_handle_repeating(AwnEffectsAnimation * anim)
{
  gboolean effect_stopped = TRUE;
  gboolean max_reached = awn_effect_check_max_loops(anim);
  gboolean repeat = !max_reached
                    && awn_effect_check_top_effect(anim, &effect_stopped);

  if (!repeat)
  {
    gboolean unregistered = FALSE;
    AwnEffects *fx = anim->effects;
    AwnEffectsPrivate *priv = fx->priv;
    priv->current_effect = AWN_EFFECT_NONE;
    priv->effect_lock = FALSE;
    priv->timer_id = 0;

    if (effect_stopped)
    {
      if (anim->stop)
        anim->stop(priv->self);

      unregistered = priv->self == NULL;
      
      g_free(anim);
    }

    if (!unregistered)
      awn_effects_main_effect_loop(fx);
  }

  return repeat;
}


gboolean
awn_effect_check_max_loops(AwnEffectsAnimation * anim)
{
  gboolean max_reached = FALSE;

  if (anim->max_loops > 0)
  {
    anim->max_loops--;
    max_reached = anim->max_loops <= 0;
  }

  if (max_reached)
    awn_effects_stop(anim->effects, anim->this_effect);

  return max_reached;
}

gboolean
awn_effect_suspend_animation(AwnEffectsAnimation * anim, GSourceFunc func)
{
  // will stop the animation timer, but keeps the animation in active state
  AwnEffectsPrivate *priv = anim->effects->priv;
  priv->sleeping_func = func;
  priv->timer_id = 0;
  return FALSE;
}
