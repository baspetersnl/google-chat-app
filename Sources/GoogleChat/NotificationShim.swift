// Google Chat voor macOS
// Copyright (C) 2026 Bas Peters
//
// This program is free software: you can redistribute it and/or modify it under the terms of the
// GNU General Public License as published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
// even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
// General Public License for more details.
//
// You should have received a copy of the GNU General Public License along with this program. If not,
// see <https://www.gnu.org/licenses/>.
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// JavaScript dat in elke frame wordt geladen. WKWebView kent de Web Notification API niet,
/// dus deze shim vervangt `window.Notification` en stuurt elke notificatie naar de native app.
enum NotificationShim {
    static let source = #"""
    (() => {
        if (window.__gchatNativeBridge) return;
        window.__gchatNativeBridge = true;

        const handler = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.gchatNotification;
        if (!handler) return;

        const instances = new Map();
        let counter = 0;

        const absoluteUrl = (value) => {
            if (!value) return '';
            try { return new URL(String(value), location.href).href; } catch (e) { return ''; }
        };

        const describe = (value) => {
            try { return JSON.stringify(value)?.slice(0, 2000) ?? ''; } catch (e) { return ''; }
        };

        // notification.data van Chat bevat geen link maar een interne structuur met een GroupId:
        // [["AAAA..."]] voor een ruimte, [null, null, ["q1nl..."]] voor een privégesprek.
        const findGroup = (value, depth = 0) => {
            // Chat geeft de data als JSON-tekst mee.
            if (typeof value === 'string' && value.startsWith('[')) {
                try { value = JSON.parse(value); } catch (e) { return null; }
            }
            if (depth > 8 || !Array.isArray(value)) return null;
            if (Array.isArray(value[0]) && typeof value[0][0] === 'string' && value.length <= 3) {
                return { kind: 'space', id: value[0][0] };
            }
            if (value[0] == null && value[1] == null && Array.isArray(value[2]) && typeof value[2][0] === 'string') {
                return { kind: 'dm', id: value[2][0] };
            }
            for (const item of value) {
                const found = findGroup(item, depth + 1);
                if (found) return found;
            }
            return null;
        };

        const groupUrl = (group) => {
            const prefix = location.pathname.replace(/\/app\/.*$/, '');
            return `${location.origin}${prefix}/app/chat/${encodeURIComponent(group.id)}`;
        };

        // Opent een gesprek via de zijbalk van Chat, zodat de pagina niet herladen hoeft.
        window.__gchatOpenGroup = (kind, id) => {
            const element = document.querySelector(`[data-group-id="${kind}/${CSS.escape(id)}"]`);
            if (!element) return 'missing';
            const target = element.closest('a, [role="link"], [role="button"], [role="option"], [role="listitem"]')
                || element.querySelector('a, [role="link"], [role="button"]')
                || element;
            target.click();
            return 'clicked';
        };

        class NativeNotification extends EventTarget {
            constructor(title, options = {}, source = 'page') {
                super();
                this.source = source;
                this.clickListeners = 0;
                this.id = `${Date.now()}-${++counter}`;
                this.title = String(title ?? '');
                this.body = String(options.body ?? '');
                this.tag = String(options.tag ?? '');
                this.icon = absoluteUrl(options.icon);
                this.data = options.data ?? null;
                this.silent = Boolean(options.silent);
                this.onclick = null;
                this.onshow = null;
                this.onclose = null;
                this.onerror = null;

                instances.set(this.id, this);
                if (instances.size > 200) instances.delete(instances.keys().next().value);

                handler.postMessage({
                    type: 'show',
                    id: this.id,
                    title: this.title,
                    body: this.body,
                    tag: this.tag,
                    icon: this.icon,
                    silent: this.silent,
                    source: this.source,
                    data: describe(this.data),
                });

                setTimeout(() => this._emit('show'), 0);
            }

            addEventListener(type, listener, options) {
                if (type === 'click') this.clickListeners++;
                super.addEventListener(type, listener, options);
            }

            close() {
                handler.postMessage({ type: 'close', id: this.id, tag: this.tag });
                instances.delete(this.id);
                this._emit('close');
            }

            _emit(type) {
                const event = new Event(type, { cancelable: true });
                const property = this['on' + type];
                if (typeof property === 'function') property.call(this, event);
                this.dispatchEvent(event);
            }

            static get permission() { return 'granted'; }
            static get maxActions() { return 0; }

            static requestPermission(callback) {
                if (typeof callback === 'function') callback('granted');
                return Promise.resolve('granted');
            }
        }

        // Geeft terug wat er gebeurde, zodat de app zelf naar het gesprek kan gaan als de
        // pagina niets met de klik doet (bij service-worker-notificaties luistert er niemand).
        window.__gchatNotificationClicked = (id) => {
            const notification = instances.get(id);
            if (!notification) return { found: false };
            const hasHandler = typeof notification.onclick === 'function' || notification.clickListeners > 0;
            window.focus();
            notification._emit('click');
            const group = findGroup(notification.data);
            return {
                found: true,
                source: notification.source,
                hasHandler,
                kind: group ? group.kind : '',
                group: group ? group.id : '',
                target: group ? groupUrl(group) : '',
            };
        };

        Object.defineProperty(window, 'Notification', {
            value: NativeNotification,
            writable: true,
            configurable: true,
        });

        if (navigator.permissions && navigator.permissions.query) {
            const query = navigator.permissions.query.bind(navigator.permissions);
            navigator.permissions.query = (descriptor) => {
                if (descriptor && descriptor.name === 'notifications') {
                    const status = new EventTarget();
                    status.state = 'granted';
                    status.name = 'notifications';
                    status.onchange = null;
                    return Promise.resolve(status);
                }
                return query(descriptor);
            };
        }

        if (window.ServiceWorkerRegistration) {
            ServiceWorkerRegistration.prototype.showNotification = function (title, options) {
                new NativeNotification(title, options || {}, 'serviceWorker');
                return Promise.resolve();
            };
            ServiceWorkerRegistration.prototype.getNotifications = function () {
                return Promise.resolve([]);
            };
        }
    })();
    """#
}
