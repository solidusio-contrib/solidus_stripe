SolidusStripe.CartPageCheckout = function() {
  SolidusStripe.Payment.call(this);

  this.errorElement = $('#stripe_card_errors');
};

SolidusStripe.CartPageCheckout.prototype = Object.create(SolidusStripe.Payment.prototype);
Object.defineProperty(SolidusStripe.CartPageCheckout.prototype, 'constructor', {
  value: SolidusStripe.CartPageCheckout,
  enumerable: false,
  writable: true
});

SolidusStripe.CartPageCheckout.prototype.init = function() {
  this.setUpPaymentRequest({requestShipping: true});
};

SolidusStripe.CartPageCheckout.prototype.showError = function(error) {
  var message = error.message || error;

  this.errorElement.text(message).show();
};

SolidusStripe.CartPageCheckout.prototype.submitPayment = function(payment) {
  var showError = this.showError.bind(this);
  var prTokenHandler = this.prTokenHandler.bind(this);

  $.ajax({
    url: $('[data-submit-url]').data('submit-url'),
    headers: {
      'X-Spree-Order-Token': $('[data-order-token]').data('order-token')
    },
    type: 'PATCH',
    contentType: 'application/json',
    data: JSON.stringify(prTokenHandler(payment.paymentMethod)),
    success: function() {
      window.location = $('[data-complete-url]').data('complete-url');
    },
    error: function(xhr,status,error) {
      showError(xhr.responseJSON.error);
    }
  });
};

SolidusStripe.CartPageCheckout.prototype.onPrPayment = function(payment) {
  var createIntent = this.createIntent.bind(this);

  fetch('/stripe/update_order', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      shipping_address: payment.shippingAddress,
      shipping_option: payment.shippingOption,
      email: payment.payerEmail,
      name: payment.payerName,
      authenticity_token: this.authToken
    })
  }).then(function(response) {
    response.json().then(function(json) {
      createIntent(json, payment);
    })
  });
};

SolidusStripe.CartPageCheckout.prototype.createIntent = function(result, payment) {
  var handleServerResponse = this.handleServerResponse.bind(this);

  if (result.error) {
    this.completePaymentRequest(payment, 'fail');
    this.showError(result.error);
  } else {
    if (payment.error) {
      this.showError(payment.error.message);
    } else {
      fetch('/stripe/create_intent', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          form_data: payment.shippingAddress,
          spree_payment_method_id: this.config.id,
          stripe_payment_method_id: payment.paymentMethod.id,
          authenticity_token: this.authToken
        })
      }).then(function(response) {
        response.json().then(function(result) {
          handleServerResponse(result, payment)
        })
      });
    }
  }
};

SolidusStripe.CartPageCheckout.prototype.onPrButtonMounted = function(buttonId, success) {
  var container = document.getElementById(buttonId).parentElement;

  if (success) {
    container.style.display = '';
  } else {
    container.style.display = 'none';
  }
};

SolidusStripe.CartPageCheckout.prototype.prTokenHandler = function(token) {
  return {
    order: {
      payments_attributes: [
        {
          payment_method_id: this.config.id,
          source_attributes: {
            gateway_payment_profile_id: token.id,
            last_digits: token.card.last4,
            month: token.card.exp_month,
            year: token.card.exp_year
          }
        }
      ]
    }
  }
};
