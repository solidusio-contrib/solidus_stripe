SolidusStripe.Elements = function() {
  SolidusStripe.Payment.call(this);

  this.form = this.element.parents('form');
  this.errorElement = this.form.find('#stripe_card_errors');
  this.submitButton = this.form.find('input[type="submit"]');
};

SolidusStripe.Elements.prototype = Object.create(SolidusStripe.Payment.prototype);
Object.defineProperty(SolidusStripe.Elements.prototype, 'constructor', {
  value: SolidusStripe.Elements,
  enumerable: false,
  writable: true
});

SolidusStripe.Elements.prototype.init = function() {
  this.initElements();
};

SolidusStripe.Elements.prototype.initElements = function() {
  var cardExpiry = this.elements.create('cardExpiry', this.cardExpiryElementOptions());
  cardExpiry.mount('#stripe_card_expiry');

  var cardCvc = this.elements.create('cardCvc', this.cardCvcElementOptions());
  cardCvc.mount('#stripe_card_cvc');

  this.cardNumber = this.elements.create('cardNumber', this.cardNumberElementOptions());
  this.cardNumber.mount('#stripe_card_number');

  this.form.bind('submit', this.onFormSubmit.bind(this));

  // Listen for errors from each input field.
  // Adapted from https://github.com/stripe/elements-examples/blob/master/js/index.js
  var savedErrors = {};
  [cardExpiry, cardCvc, this.cardNumber].forEach(function(element, idx) {
    element.on('change', function(event) {
      if (event.error) {
        savedErrors[idx] = event.error.message;
        this.showError(event.error.message);
      } else {
        savedErrors[idx] = null;

        // Loop over the saved errors and find the first one, if any.
        var nextError = Object.keys(savedErrors)
          .sort()
          .reduce(function(maybeFoundError, key) {
            return maybeFoundError || savedErrors[key];
          }, null);

        if (nextError) {
          // Now that they've fixed the current error, show another one.
          this.showError(nextError);
        } else {
          // The user fixed the last error; no more errors.
          this.errorElement.hide().text('');
        }
      }
    }.bind(this));
  }.bind(this));
};

SolidusStripe.Elements.prototype.baseStyle = function () {
  return {
    base: {
      color: 'black',
      fontFamily: '"Helvetica Neue", Helvetica, sans-serif',
      fontSmoothing: 'antialiased',
      fontSize: '14px',
      '::placeholder': {
        color: 'silver'
      }
    },
    invalid: {
      color: 'red',
      iconColor: 'red'
    }
  };
};

SolidusStripe.Elements.prototype.cardNumberElementOptions = function () {
  return {
    style: this.baseStyle()
  }
}

SolidusStripe.Elements.prototype.cardExpiryElementOptions = function () {
  return {
    style: this.baseStyle()
  }
}

SolidusStripe.Elements.prototype.cardCvcElementOptions = function () {
  return {
    style: this.baseStyle()
  }
}

SolidusStripe.Elements.prototype.showError = function(error) {
  var message = error.message || error;

  this.errorElement.text(message).show();
  this.submitButton.removeAttr('disabled').removeClass('disabled');
};

SolidusStripe.Elements.prototype.onFormSubmit = function(event) {
  if (this.element.is(':visible')) {
    event.preventDefault();

    var onTokenCreate = function(result) {
      if (result.error) {
        this.showError(result.error.message);
      } else {
        this.elementsTokenHandler(result.token);
        this.form[0].submit();
      }
    };

    this.stripe.createToken(this.cardNumber).then(onTokenCreate.bind(this));
  }
};

SolidusStripe.Elements.prototype.elementsTokenHandler = function(token) {
  var mapCC = function(ccType) {
    if (ccType === 'MasterCard' || ccType === 'mastercard') {
      return 'mastercard';
    } else if (ccType === 'Visa' || ccType === 'visa') {
      return 'visa';
    } else if (ccType === 'American Express' || ccType === 'amex') {
      return 'amex';
    } else if (ccType === 'Discover' || ccType === 'discover') {
      return 'discover';
    } else if (ccType === 'Diners Club' || ccType === 'diners') {
      return 'dinersclub';
    } else if (ccType === 'JCB' || ccType === 'jcb') {
      return 'jcb';
    } else if (ccType === 'Unionpay' || ccType === 'unionpay') {
      return 'unionpay';
    }
  };

  var baseSelector = `<input type='hidden' class='stripeToken' name='payment_source[${this.config.id}]`;

  this.element.append(`${baseSelector}[gateway_payment_profile_id]' value='${token.id}'/>`);
  this.element.append(`${baseSelector}[last_digits]' value='${token.card.last4}'/>`);
  this.element.append(`${baseSelector}[month]' value='${token.card.exp_month}'/>`);
  this.element.append(`${baseSelector}[year]' value='${token.card.exp_year}'/>`);
  this.form.find('input#cc_type').val(mapCC(token.card.brand || token.card.type));
};
